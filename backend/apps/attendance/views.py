import math
from datetime import datetime, timedelta
from django.utils import timezone
from django.db import transaction
from django.shortcuts import get_object_or_404
from rest_framework import viewsets, permissions, status, generics
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.utils import extend_schema, OpenApiParameter, OpenApiTypes
from django_filters.rest_framework import DjangoFilterBackend

from apps.users.permissions import IsAdmin, IsTeacher, IsStudent, IsAdminOrReadOnly
from apps.academics.models import Enrollment, Section
from apps.users.models import StudentProfile
from .models import ClassSession, SessionQRCode, AttendanceRecord, Justification, AttendanceAuditLog, AttendanceAlert
from .serializers import (
    ClassSessionSerializer, SessionQRCodeSerializer, AttendanceRecordSerializer, 
    JustificationSerializer, AttendanceAuditLogSerializer, AttendanceAlertSerializer,
    AttendanceScanRequestSerializer, AttendanceManualRequestSerializer,
    AttendanceJustifyRequestSerializer, AttendanceCorrectRequestSerializer
)


def calculate_distance(lat1, lon1, lat2, lon2):
    """Haversine formula to compute distance in meters between two lat/lon points."""
    R = 6371.0088  # Earth radius in km
    lat1_rad = math.radians(float(lat1))
    lon1_rad = math.radians(float(lon1))
    lat2_rad = math.radians(float(lat2))
    lon2_rad = math.radians(float(lon2))
    
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad
    
    a = math.sin(dlat / 2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    return R * c * 1000.0


def recalculate_student_alerts(student, period):
    """Recalculate the attendance rate and update traffic light alert for a student."""
    # Find all enrollment sections for the student in this period
    enrollment_sections = Section.objects.filter(enrollments__student=student, period=period)
    # Find all sessions of those sections
    sessions = ClassSession.objects.filter(section__in=enrollment_sections, status='closed')
    total_sessions = sessions.count()
    if total_sessions == 0:
        return
        
    # Count student attendances for those sessions
    records = AttendanceRecord.objects.filter(student=student, session__in=sessions)
    
    # Present, late, or justified count as attended for percentage calculation
    attended_count = records.filter(status__in=['presente', 'tardanza', 'justificado']).count()
    
    percentage = (attended_count / total_sessions) * 100.0
    
    # Traffic light rules
    if percentage >= 85.0:
        alert_status = 'green'
    elif percentage >= 70.0:
        alert_status = 'yellow'
    else:
        alert_status = 'red'
        
    AttendanceAlert.objects.update_or_create(
        student=student,
        academic_period=period,
        defaults={
            'attendance_percentage': percentage,
            'status': alert_status
        }
    )


class ClassSessionViewSet(viewsets.ModelViewSet):
    serializer_class = ClassSessionSerializer
    permission_classes = [IsAdminOrReadOnly]

    def get_queryset(self):
        user = self.request.user
        if not user.is_authenticated:
            return ClassSession.objects.none()
            
        if user.role in ['superadmin', 'admin']:
            queryset = ClassSession.objects.all().select_related('section__course', 'classroom')
        elif user.role == 'teacher':
            queryset = ClassSession.objects.filter(section__teacher__user=user).select_related('section__course', 'classroom')
        elif user.role == 'student':
            queryset = ClassSession.objects.filter(section__enrollments__student__user=user).select_related('section__course', 'classroom')
        else:
            return ClassSession.objects.none()

        start_date = self.request.query_params.get('start_date')
        end_date = self.request.query_params.get('end_date')
        if start_date:
            queryset = queryset.filter(date__gte=start_date)
        if end_date:
            queryset = queryset.filter(date__lte=end_date)

        return queryset.order_by('date', 'start_time')

    @action(detail=True, methods=['POST'], permission_classes=[IsTeacher | IsAdmin])
    def open(self, request, pk=None):
        """Open a session and pre-populate all matriculated students with 'falta' (absent) state."""
        session = self.get_object()
        if session.status != 'scheduled':
            return Response({'detail': f'La sesión ya está {session.get_status_display()}'}, status=status.HTTP_400_BAD_REQUEST)
            
        with transaction.atomic():
            session.status = 'active'
            tolerance_mins = request.data.get('tolerance_minutes')
            if tolerance_mins is not None:
                try:
                    session.tolerance_minutes = int(tolerance_mins)
                except (ValueError, TypeError):
                    pass
            session.save()
            
            # Find all enrolled students
            enrollments = Enrollment.objects.filter(section=session.section)
            for enrollment in enrollments:
                # Pre-populate as 'falta' if not exists
                AttendanceRecord.objects.get_or_create(
                    session=session,
                    student=enrollment.student,
                    defaults={
                        'status': 'falta',
                        'recorded_by': 'system_absent'
                    }
                )
                
        return Response({'detail': 'Sesión abierta e inasistencias inicializadas correctamente', 'status': session.status})

    @action(detail=True, methods=['POST'], permission_classes=[IsTeacher | IsAdmin])
    def close(self, request, pk=None):
        """Close a session, deactivate all its QRs and recalculate alerts for all students in the section."""
        session = self.get_object()
        if session.status != 'active':
            return Response({'detail': 'Solo se pueden cerrar sesiones activas'}, status=status.HTTP_400_BAD_REQUEST)
            
        with transaction.atomic():
            session.status = 'closed'
            session.save()
            
            # Deactivate QRs
            session.qrs.filter(is_active=True).update(is_active=False)
            
            # Recalculate alerts for all students enrolled in this section
            enrollments = Enrollment.objects.filter(section=session.section)
            for enrollment in enrollments:
                recalculate_student_alerts(enrollment.student, session.section.period)
                
        return Response({'detail': 'Sesión cerrada y semáforos recalculados correctamente', 'status': session.status})

    @action(detail=True, methods=['POST'], url_path='generate-qr', permission_classes=[IsTeacher | IsAdmin])
    def generate_qr(self, request, pk=None):
        """Generate a new dynamic QR token with expiration (default 30 seconds)."""
        session = self.get_object()
        if session.status != 'active':
            return Response({'detail': 'Debe abrir la sesión antes de generar un código QR'}, status=status.HTTP_400_BAD_REQUEST)
            
        # Deactivate previous active QR codes for this session
        session.qrs.filter(is_active=True).update(is_active=False)
        
        # Calculate expiration
        duration_seconds = int(request.data.get('duration_seconds', 30))
        expires_at = timezone.now() + timedelta(seconds=duration_seconds)
        
        qr = SessionQRCode.objects.create(
            session=session,
            expires_at=expires_at,
            is_active=True
        )
        
        serializer = SessionQRCodeSerializer(qr)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['GET'])
    def attendance_summary(self, request, pk=None):
        """Get summary count of current attendance records in the session."""
        session = self.get_object()
        records = AttendanceRecord.objects.filter(session=session)
        
        summary = {
            'total': records.count(),
            'presente': records.filter(status='presente').count(),
            'tardanza': records.filter(status='tardanza').count(),
            'falta': records.filter(status='falta').count(),
            'retiro_anticipado': records.filter(status='retiro_anticipado').count(),
            'justificado': records.filter(status='justificado').count(),
        }
        return Response(summary)

    @action(detail=True, methods=['GET'], permission_classes=[permissions.AllowAny], url_path='export-pdf')
    def export_pdf(self, request, pk=None):
        """Export session attendance to a beautifully styled PDF."""
        # Allow passing token in query parameters (for browser direct download)
        user = request.user
        token = request.query_params.get('token')
        if token and (not user or not user.is_authenticated):
            try:
                from rest_framework_simplejwt.authentication import JWTAuthentication
                jwt_auth = JWTAuthentication()
                validated_token = jwt_auth.get_validated_token(token)
                user = jwt_auth.get_user(validated_token)
                request.user = user
            except Exception:
                pass

        if not user or not user.is_authenticated:
            return Response({'detail': 'Las credenciales de autenticación no fueron provistas.'}, status=status.HTTP_401_UNAUTHORIZED)

        if user.role not in ['teacher', 'admin', 'superadmin']:
            return Response({'detail': 'No tiene permiso para realizar esta acción.'}, status=status.HTTP_403_FORBIDDEN)

        session = self.get_object()
        if user.role == 'teacher' and session.section.teacher.user != user:
            return Response({'detail': 'No tiene permiso para ver esta sesión.'}, status=status.HTTP_403_FORBIDDEN)
        
        import io
        from django.http import FileResponse
        from django.utils import timezone
        from reportlab.lib.pagesizes import letter
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.lib import colors
        
        section = session.section
        course = section.course
        classroom = session.classroom
        records = session.attendances.all().select_related('student__user').order_by('student__user__last_name', 'student__user__first_name')
        
        total_students = records.count()
        present_count = records.filter(status='presente').count()
        tardy_count = records.filter(status='tardanza').count()
        absent_count = records.filter(status='falta').count()
        justified_count = records.filter(status='justificado').count() + records.filter(justification__status='approved').count()
        
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=letter,
            rightMargin=40,
            leftMargin=40,
            topMargin=40,
            bottomMargin=40
        )
        
        styles = getSampleStyleSheet()
        
        title_style = ParagraphStyle(
            name='ReportTitle',
            parent=styles['Heading1'],
            fontName='Helvetica-Bold',
            fontSize=20,
            textColor=colors.HexColor('#0F172A'),
            spaceAfter=15
        )
        
        body_style = ParagraphStyle(
            name='ReportBody',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=10,
            textColor=colors.HexColor('#1E293B')
        )
        
        cell_style = ParagraphStyle(
            name='CellText',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=9,
            textColor=colors.HexColor('#334155')
        )

        cell_header_style = ParagraphStyle(
            name='CellHeader',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=9,
            textColor=colors.white
        )

        elements = []
        
        elements.append(Paragraph("REPORTE OFICIAL DE ASISTENCIA", title_style))
        elements.append(Spacer(1, 10))
        
        meta_data = [
            [
                Paragraph(f"<b>Curso:</b> {course.name} ({course.code})", body_style),
                Paragraph(f"<b>Fecha:</b> {session.date.strftime('%d/%m/%Y')}", body_style)
            ],
            [
                Paragraph(f"<b>Sección:</b> {section.code}", body_style),
                Paragraph(f"<b>Horario:</b> {session.start_time.strftime('%H:%M')} - {session.end_time.strftime('%H:%M')}", body_style)
            ],
            [
                Paragraph(f"<b>Docente:</b> {section.teacher.user.get_full_name()}", body_style),
                Paragraph(f"<b>Aula:</b> {classroom.name}", body_style)
            ]
        ]
        
        meta_table = Table(meta_data, colWidths=[270, 270])
        meta_table.setStyle(TableStyle([
            ('ALIGN', (0,0), (-1,-1), 'LEFT'),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('BOTTOMPADDING', (0,0), (-1,-1), 4),
            ('TOPPADDING', (0,0), (-1,-1), 4),
        ]))
        
        elements.append(meta_table)
        elements.append(Spacer(1, 15))
        
        summary_data = [
            [
                Paragraph("<b>Matriculados</b>", body_style),
                Paragraph("<b>Presentes</b>", body_style),
                Paragraph("<b>Tardanzas</b>", body_style),
                Paragraph("<b>Faltas</b>", body_style),
                Paragraph("<b>Justificados</b>", body_style),
            ],
            [
                Paragraph(str(total_students), body_style),
                Paragraph(f"<font color='#10B981'><b>{present_count}</b></font>", body_style),
                Paragraph(f"<font color='#F59E0B'><b>{tardy_count}</b></font>", body_style),
                Paragraph(f"<font color='#EF4444'><b>{absent_count}</b></font>", body_style),
                Paragraph(f"<font color='#817BFF'><b>{justified_count}</b></font>", body_style),
            ]
        ]
        summary_table = Table(summary_data, colWidths=[108, 108, 108, 108, 108])
        summary_table.setStyle(TableStyle([
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#F8FAFC')),
            ('GRID', (0,0), (-1,-1), 1, colors.HexColor('#E2E8F0')),
            ('TOPPADDING', (0,0), (-1,-1), 6),
            ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ]))
        elements.append(summary_table)
        elements.append(Spacer(1, 20))
        
        table_headers = [
            Paragraph("<b>N°</b>", cell_header_style),
            Paragraph("<b>Código</b>", cell_header_style),
            Paragraph("<b>Alumno</b>", cell_header_style),
            Paragraph("<b>Estado</b>", cell_header_style),
            Paragraph("<b>Marcación</b>", cell_header_style),
            Paragraph("<b>Método</b>", cell_header_style),
        ]
        
        table_rows = [table_headers]
        
        for idx, rec in enumerate(records, 1):
            student = rec.student
            user = student.user
            
            status_text = rec.get_status_display()
            justification = getattr(rec, 'justification', None)
            if justification and justification.status == 'approved':
                status_text = 'Justificado'
                
            recorded_time = '-'
            if rec.recorded_at:
                recorded_time = timezone.localtime(rec.recorded_at).strftime('%H:%M')
                
            recorded_by = rec.get_recorded_by_display() if rec.recorded_by else '-'
            
            table_rows.append([
                Paragraph(str(idx), cell_style),
                Paragraph(student.student_code, cell_style),
                Paragraph(user.get_full_name(), cell_style),
                Paragraph(status_text, cell_style),
                Paragraph(recorded_time, cell_style),
                Paragraph(recorded_by, cell_style),
            ])
            
        attend_table = Table(table_rows, colWidths=[30, 80, 200, 100, 60, 70])
        
        t_style = [
            ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#1E1B4B')),
            ('ALIGN', (0,0), (-1,-1), 'LEFT'),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
            ('TOPPADDING', (0,0), (-1,-1), 5),
            ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ]
        
        for r in range(1, len(table_rows)):
            if r % 2 == 0:
                t_style.append(('BACKGROUND', (0, r), (-1, r), colors.HexColor('#F8FAFC')))
            
            rec_status = records[r-1].status
            just = getattr(records[r-1], 'justification', None)
            if just and just.status == 'approved':
                rec_status = 'justificado'
                
            if rec_status == 'presente':
                t_style.append(('TEXTCOLOR', (3, r), (3, r), colors.HexColor('#10B981')))
            elif rec_status == 'tardanza':
                t_style.append(('TEXTCOLOR', (3, r), (3, r), colors.HexColor('#D97706')))
            elif rec_status == 'falta':
                t_style.append(('TEXTCOLOR', (3, r), (3, r), colors.HexColor('#DC2626')))
            elif rec_status == 'justificado':
                t_style.append(('TEXTCOLOR', (3, r), (3, r), colors.HexColor('#6366F1')))
                
        attend_table.setStyle(TableStyle(t_style))
        elements.append(attend_table)
        
        doc.build(elements)
        buffer.seek(0)
        
        filename = f"asistencia_{course.code}_{session.date.strftime('%Y%m%d')}.pdf"
        return FileResponse(buffer, as_attachment=True, filename=filename, content_type='application/pdf')


class AttendanceRecordViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = AttendanceRecordSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['session', 'student', 'status']

    def get_queryset(self):
        user = self.request.user
        if not user.is_authenticated:
            return AttendanceRecord.objects.none()
            
        # Keep support for session_id query param
        session_id = self.request.query_params.get('session_id')
        queryset = AttendanceRecord.objects.all().select_related('student__user', 'session__section__course')
        
        if session_id:
            queryset = queryset.filter(session_id=session_id)
            
        if user.role in ['superadmin', 'admin']:
            pass
        elif user.role == 'teacher':
            queryset = queryset.filter(session__section__teacher__user=user)
        elif user.role == 'student':
            queryset = queryset.filter(student__user=user)
        else:
            return AttendanceRecord.objects.none()

        start_date = self.request.query_params.get('start_date')
        end_date = self.request.query_params.get('end_date')
        if start_date:
            queryset = queryset.filter(session__date__gte=start_date)
        if end_date:
            queryset = queryset.filter(session__date__lte=end_date)

        return queryset.order_by('-session__date', '-session__start_time')

    @action(detail=True, methods=['GET'], permission_classes=[IsTeacher | IsAdmin])
    def audit_logs(self, request, pk=None):
        record = self.get_object()
        logs = record.audit_logs.all().select_related('changed_by')
        serializer = AttendanceAuditLogSerializer(logs, many=True)
        return Response(serializer.data)


class AttendanceScanAPIView(APIView):
    permission_classes = [IsStudent]

    @extend_schema(
        request=AttendanceScanRequestSerializer,
        responses={200: AttendanceRecordSerializer}
    )
    def post(self, request):
        serializer = AttendanceScanRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        qr_code_val = serializer.validated_data.get('qr_code')
        lat = serializer.validated_data.get('latitude')
        lon = serializer.validated_data.get('longitude')
            
        # Find QR Code
        qr = SessionQRCode.objects.filter(code=qr_code_val, is_active=True).select_related('session__classroom', 'session__section').first()
        if not qr:
            return Response({'detail': 'Código QR inválido o expirado'}, status=status.HTTP_400_BAD_REQUEST)
            
        # Check if expired
        if timezone.now() > qr.expires_at:
            qr.is_active = False
            qr.save()
            return Response({'detail': 'El código QR ha expirado'}, status=status.HTTP_400_BAD_REQUEST)
            
        session = qr.session
        if session.status != 'active':
            return Response({'detail': 'La sesión de clase no está activa'}, status=status.HTTP_400_BAD_REQUEST)
            
        # Check student profile
        student = getattr(request.user, 'student_profile', None)
        if not student:
            return Response({'detail': 'El usuario actual no tiene perfil de estudiante'}, status=status.HTTP_403_FORBIDDEN)
            
        # Validate student enrollment in this section
        is_enrolled = Enrollment.objects.filter(student=student, section=session.section).exists()
        if not is_enrolled:
            return Response({'detail': 'No estás matriculado en esta sección de clase'}, status=status.HTTP_403_FORBIDDEN)
            
        # Validate geolocation (if enabled/coordinates provided)
        geo_valid = True
        distance = None
        classroom = session.classroom
        
        if classroom and classroom.latitude and classroom.longitude:
            if not lat or not lon:
                return Response({'detail': 'Esta sesión requiere compartir tu ubicación (GPS)'}, status=status.HTTP_400_BAD_REQUEST)
            
            distance = calculate_distance(lat, lon, classroom.latitude, classroom.longitude)
            if distance > classroom.radius_meters:
                geo_valid = False
                return Response({'detail': f'Estás fuera del rango permitido del aula ({int(distance)} metros de distancia, límite {classroom.radius_meters}m)'}, status=status.HTTP_400_BAD_REQUEST)

        # Get or create record (we pre-populated as 'falta' on session open)
        record, created = AttendanceRecord.objects.get_or_create(
            session=session,
            student=student,
            defaults={'status': 'falta'}
        )
        
        # Double scan check
        if record.status in ['presente', 'tardanza']:
            if record.check_out is None:
                now_time = timezone.now()
                with transaction.atomic():
                    record.check_out = now_time
                    record.save()
                    
                    AttendanceAuditLog.objects.create(
                        attendance_record=record,
                        action='update',
                        changed_by=request.user,
                        old_status=record.status,
                        new_status=record.status,
                        reason='Marcación de salida (Check-out) por escaneo QR de alumno'
                    )
                serializer = AttendanceRecordSerializer(record)
                res_data = serializer.data
                res_data['detail'] = 'Salida registrada correctamente.'
                return Response(res_data)
            else:
                return Response({'detail': 'Ya registraste tu entrada y tu salida para esta sesión'}, status=status.HTTP_400_BAD_REQUEST)
            
        # Check tolerance window
        # Get session start time combined with today's date
        start_datetime = datetime.combine(session.date, session.start_time)
        start_datetime = timezone.make_aware(start_datetime)
        
        now_time = timezone.now()
        time_difference = now_time - start_datetime
        minutes_late = time_difference.total_seconds() / 60.0
        
        # Determine status
        if minutes_late <= session.tolerance_minutes:
            new_status = 'presente'
            detail_msg = 'Entrada registrada correctamente (PRESENTE).'
        elif minutes_late <= (session.tolerance_minutes * 2):
            new_status = 'tardanza'
            detail_msg = f'Escaneo registrado como TARDANZA ({int(minutes_late)} minutos de retraso).'
        else:
            new_status = 'falta'
            detail_msg = f'Escaneo registrado tarde ({int(minutes_late)} minutos). Se registró como FALTA.'
        
        with transaction.atomic():
            record.status = new_status
            record.recorded_at = now_time
            record.recorded_by = 'student_qr'
            record.latitude = lat
            record.longitude = lon
            record.geo_valid = geo_valid
            record.save()
            
            # Log audit
            AttendanceAuditLog.objects.create(
                attendance_record=record,
                action='create' if created else 'update',
                changed_by=request.user,
                old_status='falta' if not created else None,
                new_status=new_status,
                reason='Marcación por escaneo QR de alumno'
            )
            
        serializer = AttendanceRecordSerializer(record)
        res_data = serializer.data
        res_data['detail'] = detail_msg
        return Response(res_data)


class AttendanceManualAPIView(APIView):
    permission_classes = [IsTeacher | IsAdmin]

    @extend_schema(
        request=AttendanceManualRequestSerializer,
        responses={200: AttendanceRecordSerializer}
    )
    def post(self, request):
        serializer = AttendanceManualRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        attendance_id = serializer.validated_data.get('attendance_id')
        new_status = serializer.validated_data.get('status')
        reason = serializer.validated_data.get('reason')
        
        record = get_object_or_404(AttendanceRecord, id=attendance_id)
        
        # Row level permission check for teacher
        if request.user.role == 'teacher' and record.session.section.teacher.user != request.user:
            return Response({'detail': 'No tienes permisos sobre esta sección de clase'}, status=status.HTTP_403_FORBIDDEN)
            
        old_status = record.status
        with transaction.atomic():
            record.status = new_status
            record.recorded_by = 'teacher_manual' if request.user.role == 'teacher' else 'admin_manual'
            record.recorded_at = timezone.now()
            record.save()
            
            # Create Audit Log
            AttendanceAuditLog.objects.create(
                attendance_record=record,
                action='update',
                changed_by=request.user,
                old_status=old_status,
                new_status=new_status,
                reason=reason
            )
            
            # Recalculate alerts if session is closed
            if record.session.status == 'closed':
                recalculate_student_alerts(record.student, record.session.section.period)
                
        serializer = AttendanceRecordSerializer(record)
        return Response(serializer.data)


class AttendanceJustifyAPIView(APIView):
    permission_classes = [IsStudent]

    @extend_schema(
        request=AttendanceJustifyRequestSerializer,
        responses={201: JustificationSerializer}
    )
    def post(self, request, pk=None):
        serializer = AttendanceJustifyRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        # We can accept attendance_id from URL path (pk) or body. Let's support pk from path if available
        attendance_id = pk or serializer.validated_data.get('attendance_id')
        reason = serializer.validated_data.get('reason')
        document_url = serializer.validated_data.get('document_url') or ''
        
        if not attendance_id:
            return Response({'detail': 'El campo attendance_id es obligatorio'}, status=status.HTTP_400_BAD_REQUEST)
            
        record = get_object_or_404(AttendanceRecord, id=attendance_id)
        
        # Verify the record belongs to the current student
        if record.student.user != request.user:
            return Response({'detail': 'No puedes justificar inasistencias de otros alumnos'}, status=status.HTTP_403_FORBIDDEN)
            
        # Only allow justifications for 'falta' or 'tardanza'
        if record.status not in ['falta', 'tardanza']:
            return Response({'detail': 'Solo puedes justificar faltas o tardanzas'}, status=status.HTTP_400_BAD_REQUEST)
            
        justification, created = Justification.objects.get_or_create(
            attendance_record=record,
            defaults={
                'reason': reason,
                'document_url': document_url,
                'status': 'pending'
            }
        )
        
        if not created:
            justification.reason = reason
            justification.document_url = document_url
            justification.status = 'pending'
            justification.save()
            
        serializer = JustificationSerializer(justification)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class AttendanceCorrectAPIView(APIView):
    permission_classes = [IsTeacher | IsAdmin]

    @extend_schema(
        request=AttendanceCorrectRequestSerializer,
        responses={200: JustificationSerializer}
    )
    def post(self, request, pk=None):
        serializer = AttendanceCorrectRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        justification_id = pk or serializer.validated_data.get('justification_id')
        new_status = serializer.validated_data.get('status')  # 'approved' or 'rejected'
        override_status = serializer.validated_data.get('override_status')  # Force record state (e.g. 'justificado')
        reason = serializer.validated_data.get('reason')
        
        if not justification_id:
            return Response({'detail': 'El campo justification_id es obligatorio'}, status=status.HTTP_400_BAD_REQUEST)
            
        justification = get_object_or_404(Justification, id=justification_id)
        record = justification.attendance_record
        
        # Teacher permissions check
        if request.user.role == 'teacher' and record.session.section.teacher.user != request.user:
            return Response({'detail': 'No tienes permisos sobre esta sección de clase'}, status=status.HTTP_403_FORBIDDEN)
            
        with transaction.atomic():
            justification.status = new_status
            justification.resolved_by = request.user
            justification.resolved_at = timezone.now()
            justification.save()
            
            # Update record status based on justification result
            old_record_status = record.status
            record_changed = False
            
            if new_status == 'approved':
                record.status = override_status or 'justificado'
                record_changed = True
            elif new_status == 'rejected' and override_status:
                record.status = override_status
                record_changed = True
                
            if record_changed:
                record.recorded_by = 'teacher_manual' if request.user.role == 'teacher' else 'admin_manual'
                record.save()
                
                # Audit Log
                AttendanceAuditLog.objects.create(
                    attendance_record=record,
                    action='update',
                    changed_by=request.user,
                    old_status=old_record_status,
                    new_status=record.status,
                    reason=f"Corrección por resolución de justificación: {reason}"
                )
                
                # Recalculate alerts if session is closed
                if record.session.status == 'closed':
                    recalculate_student_alerts(record.student, record.session.section.period)
                    
        serializer = JustificationSerializer(justification)
        return Response(serializer.data)


class JustificationViewSet(viewsets.ModelViewSet):
    serializer_class = JustificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        session_id = self.request.query_params.get('session_id')
        queryset = Justification.objects.all().select_related('attendance_record__student__user', 'resolved_by')
        
        if session_id:
            queryset = queryset.filter(attendance_record__session_id=session_id)
            
        if user.role in ['superadmin', 'admin']:
            return queryset
        elif user.role == 'teacher':
            return queryset.filter(attendance_record__session__section__teacher__user=user)
        elif user.role == 'student':
            return queryset.filter(attendance_record__student__user=user)
        return Justification.objects.none()


class AttendanceAlertViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = AttendanceAlertSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        queryset = AttendanceAlert.objects.all().select_related('student__user', 'academic_period')
        
        # Filter by student or period
        student_id = self.request.query_params.get('student_id')
        period_id = self.request.query_params.get('period_id')
        status_filter = self.request.query_params.get('status')
        
        if student_id:
            queryset = queryset.filter(student_id=student_id)
        if period_id:
            queryset = queryset.filter(academic_period_id=period_id)
        if status_filter:
            queryset = queryset.filter(status=status_filter)
            
        if user.role in ['superadmin', 'admin']:
            return queryset
        elif user.role == 'teacher':
            # Teachers can see alerts of students matriculated in their sections
            sections = Section.objects.filter(teacher__user=user)
            students = StudentProfile.objects.filter(enrollments__section__in=sections)
            return queryset.filter(student__in=students).distinct()
        elif user.role == 'student':
            return queryset.filter(student__user=user)
        return AttendanceAlert.objects.none()
