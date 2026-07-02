from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from apps.users.models import StudentProfile, TeacherProfile
from apps.academics.models import Institution, Campus, Classroom, Program, AcademicPeriod, Course, Section, Enrollment
from apps.attendance.models import ClassSession, AttendanceRecord, AttendanceAlert
from apps.attendance.views import recalculate_student_alerts
from django.utils import timezone
from datetime import date, time, timedelta
import random

User = get_user_model()


class Command(BaseCommand):
    help = 'Seed the database with realistic sample data for the QR Attendance System MVP'

    def handle(self, *args, **kwargs):
        self.stdout.write('Iniciando carga de datos seed...')
        
        # 1. Create Admins
        admin_email = 'admin@demo.com'
        if not User.objects.filter(email=admin_email).exists():
            admin_user = User.objects.create_superuser(
                email=admin_email,
                password='password',
                first_name='Admin',
                last_name='Institucional'
            )
            self.stdout.write(f'Usuario administrador creado: {admin_email}')
        else:
            admin_user = User.objects.get(email=admin_email)

        # 2. Create Institution & Campus
        inst, _ = Institution.objects.get_or_create(
            code='INST01',
            defaults={'name': 'Instituto Tecnológico Superior'}
        )
        
        campus, _ = Campus.objects.get_or_create(
            institution=inst,
            name='Sede Central - Surco',
            defaults={'address': 'Av. Primavera 1200, Santiago de Surco, Lima'}
        )

        # 3. Create Classrooms
        # Coordinates near Surco/Barranco, Lima
        classroom1, _ = Classroom.objects.get_or_create(
            campus=campus,
            name='Aula 401 - Pabellón A',
            defaults={
                'latitude': -12.124600,
                'longitude': -77.027800,
                'radius_meters': 100
            }
        )
        classroom2, _ = Classroom.objects.get_or_create(
            campus=campus,
            name='Laboratorio de Software 102',
            defaults={
                'latitude': -12.125000,
                'longitude': -77.028000,
                'radius_meters': 50
            }
        )

        # 4. Create Academic Period
        today = timezone.now().date()
        period, _ = AcademicPeriod.objects.get_or_create(
            name='2026-I',
            defaults={
                'start_date': today - timedelta(days=60),
                'end_date': today + timedelta(days=60),
                'is_active': True
            }
        )

        # 5. Create Programs
        prog_is, _ = Program.objects.get_or_create(
            code='PROG-IS',
            campus=campus,
            defaults={'name': 'Ingeniería de Software'}
        )
        prog_cc, _ = Program.objects.get_or_create(
            code='PROG-CC',
            campus=campus,
            defaults={'name': 'Ciencia de la Computación'}
        )

        # 6. Create 5 Courses
        courses_data = [
            (prog_is, 'Programación Orientada a Objetos', 'POO-101'),
            (prog_is, 'Arquitectura de Software', 'ARS-302'),
            (prog_is, 'Desarrollo de Aplicaciones Móviles', 'DAM-401'),
            (prog_cc, 'Estructuras de Datos y Algoritmos', 'EDA-201'),
            (prog_cc, 'Bases de Datos Distribuidas', 'BDD-301'),
        ]
        courses = []
        for prog, name, code in courses_data:
            course, _ = Course.objects.get_or_create(
                code=code,
                defaults={'program': prog, 'name': name}
            )
            courses.append(course)

        # 7. Create 5 Teachers
        teachers = []
        for i in range(1, 6):
            t_email = f'docente{i}@demo.com'
            t_code = f'DOC00{i}'
            
            user, created = User.objects.get_or_create(
                email=t_email,
                defaults={
                    'username': t_email,
                    'first_name': f'Profesor {i}',
                    'last_name': f'Docente',
                    'role': 'teacher'
                }
            )
            if created:
                user.set_password('password')
                user.save()
                
            teacher_profile, _ = TeacherProfile.objects.get_or_create(
                user=user,
                defaults={'teacher_code': t_code}
            )
            teachers.append(teacher_profile)
            self.stdout.write(f'Docente creado: {t_email}')

        # 8. Create 50 Students
        students = []
        for i in range(1, 51):
            s_email = f'alumno{i}@demo.com'
            s_code = f'202610{i:03d}'
            
            user, created = User.objects.get_or_create(
                email=s_email,
                defaults={
                    'username': s_email,
                    'first_name': f'Estudiante {i}',
                    'last_name': f'Apellido {i}',
                    'role': 'student'
                }
            )
            if created:
                user.set_password('password')
                user.save()
                
            student_profile, _ = StudentProfile.objects.get_or_create(
                user=user,
                defaults={'student_code': s_code}
            )
            students.append(student_profile)
            
        self.stdout.write('50 estudiantes creados/verificados.')

        # 9. Create 5 Sections
        sections = []
        for i, course in enumerate(courses):
            # Assign teachers in round robin
            teacher = teachers[i % len(teachers)]
            section, _ = Section.objects.get_or_create(
                course=course,
                code=f'NX{51+i}',
                period=period,
                defaults={'teacher': teacher}
            )
            sections.append(section)

        # 10. Enroll Students in Sections
        # Let's enroll student1 (alumno1@demo.com) in POO-101 and DAM-401 for easier manual testing
        student1 = students[0]
        Enrollment.objects.get_or_create(student=student1, section=sections[0])
        Enrollment.objects.get_or_create(student=student1, section=sections[2])
        
        # Enrol others randomly (20 students per section)
        for section in sections:
            # Get 19 other random students
            sampled = random.sample(students[1:], 19)
            # Add student1 to first and third section
            if section in [sections[0], sections[2]]:
                if student1 not in sampled:
                    Enrollment.objects.get_or_create(student=student1, section=section)
            for s in sampled:
                Enrollment.objects.get_or_create(student=s, section=section)

        self.stdout.write('Matrículas distribuidas completadas.')

        # 11. Create Sample Sessions & Attendance Records
        # Create past closed sessions to generate attendance history and alerts
        for section in sections:
            # Create 5 past sessions
            for day_offset in range(1, 6):
                session_date = today - timedelta(days=day_offset*3) # e.g. Mon, Wed, Fri
                session, created = ClassSession.objects.get_or_create(
                    section=section,
                    classroom=classroom1 if day_offset % 2 == 0 else classroom2,
                    date=session_date,
                    defaults={
                        'start_time': time(19, 0),
                        'end_time': time(21, 0),
                        'status': 'closed',
                        'tolerance_minutes': 15
                    }
                )
                
                if created:
                    # Create attendance records for enrolled students
                    enrollments = Enrollment.objects.filter(section=section)
                    for enrollment in enrollments:
                        # Random status: 70% present, 15% tardanza, 10% falta, 5% justified
                        rand = random.random()
                        if rand < 0.70:
                            rec_status = 'presente'
                            recorded_by = 'student_qr'
                        elif rand < 0.85:
                            rec_status = 'tardanza'
                            recorded_by = 'student_qr'
                        elif rand < 0.95:
                            rec_status = 'falta'
                            recorded_by = 'system_absent'
                        else:
                            rec_status = 'justificado'
                            recorded_by = 'teacher_manual'
                            
                        # Set record details
                        recorded_at = timezone.make_aware(
                            timezone.datetime.combine(session_date, time(19, 0)) + 
                            timedelta(minutes=random.randint(0, 30))
                        ) if rec_status != 'falta' else None
                        
                        AttendanceRecord.objects.create(
                            session=session,
                            student=enrollment.student,
                            status=rec_status,
                            recorded_at=recorded_at,
                            recorded_by=recorded_by,
                            latitude=classroom1.latitude if rec_status in ['presente', 'tardanza'] else None,
                            longitude=classroom1.longitude if rec_status in ['presente', 'tardanza'] else None,
                            geo_valid=True if rec_status in ['presente', 'tardanza'] else None
                        )

        self.stdout.write('Historial de sesiones pasadas y asistencias registradas.')

        # 12. Recalculate Alerts / Traffic Lights for all students
        for student in students:
            recalculate_student_alerts(student, period)
            
        self.stdout.write('Semáforos de alertas recalculados.')

        # 13. Create one scheduled/active session for today for demo scanning
        # Let's create an active session for sections[0] (POO-101) today
        demo_session, _ = ClassSession.objects.get_or_create(
            section=sections[0],
            classroom=classroom1,
            date=today,
            defaults={
                'start_time': time(8, 0),
                'end_time': time(10, 0),
                'status': 'active',
                'tolerance_minutes': 15
            }
        )
        
        # Prepopulate demo session attendances as 'falta'
        enrollments = Enrollment.objects.filter(section=sections[0])
        for enrollment in enrollments:
            AttendanceRecord.objects.get_or_create(
                session=demo_session,
                student=enrollment.student,
                defaults={
                    'status': 'falta',
                    'recorded_by': 'system_absent'
                }
            )
            
        self.stdout.write('Sesión activa creada para la demostración de hoy en POO-101.')
        self.stdout.write('Carga de datos seed exitosa.')
