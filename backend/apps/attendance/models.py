import uuid
from django.db import models
from django.contrib.auth import get_user_model
from apps.users.models import StudentProfile
from apps.academics.models import Section, Classroom, AcademicPeriod

User = get_user_model()


class ClassSession(models.Model):
    STATUS_CHOICES = (
        ('scheduled', 'Programada'),
        ('active', 'Activa (QR Abierto)'),
        ('closed', 'Cerrada'),
    )

    section = models.ForeignKey(Section, on_delete=models.CASCADE, related_name='sessions', verbose_name='Sección')
    classroom = models.ForeignKey(Classroom, on_delete=models.CASCADE, related_name='sessions', verbose_name='Aula')
    date = models.DateField(verbose_name='Fecha')
    start_time = models.TimeField(verbose_name='Hora de Inicio')
    end_time = models.TimeField(verbose_name='Hora de Fin')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='scheduled', verbose_name='Estado')
    tolerance_minutes = models.IntegerField(default=15, verbose_name='Minutos de Tolerancia para Tardanza')

    class Meta:
        verbose_name = 'Sesión de Clase'
        verbose_name_plural = 'Sesiones de Clase'
        ordering = ['date', 'start_time']

    def __str__(self):
        return f"{self.section.course.name} - {self.date} {self.start_time}"


class SessionQRCode(models.Model):
    session = models.ForeignKey(ClassSession, on_delete=models.CASCADE, related_name='qrs', verbose_name='Sesión')
    code = models.CharField(max_length=100, unique=True, default=uuid.uuid4, verbose_name='Código de Token')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Creado el')
    expires_at = models.DateTimeField(verbose_name='Expira el')
    is_active = models.BooleanField(default=True, verbose_name='Activo')

    class Meta:
        verbose_name = 'Código QR de Sesión'
        verbose_name_plural = 'Códigos QR de Sesión'

    def __str__(self):
        return f"QR {self.code[:8]} ({self.session})"


class AttendanceRecord(models.Model):
    STATUS_CHOICES = (
        ('presente', 'Presente'),
        ('tardanza', 'Tardanza'),
        ('falta', 'Falta'),
        ('retiro_anticipado', 'Retiro Anticipado'),
        ('justificado', 'Justificado'),
    )

    RECORDED_BY_CHOICES = (
        ('student_qr', 'Escaneo QR Alumno'),
        ('teacher_manual', 'Docente Manual'),
        ('admin_manual', 'Administrador Manual'),
        ('system_absent', 'Inasistencia Automática'),
    )

    session = models.ForeignKey(ClassSession, on_delete=models.CASCADE, related_name='attendances', verbose_name='Sesión')
    student = models.ForeignKey(StudentProfile, on_delete=models.CASCADE, related_name='attendances', verbose_name='Alumno')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='falta', verbose_name='Estado de Asistencia')
    recorded_at = models.DateTimeField(null=True, blank=True, verbose_name='Registrado el')
    recorded_by = models.CharField(max_length=20, choices=RECORDED_BY_CHOICES, default='system_absent', verbose_name='Registrado por')
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True, verbose_name='Latitud Marcación')
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True, verbose_name='Longitud Marcación')
    geo_valid = models.BooleanField(null=True, blank=True, verbose_name='Geolocalización Válida')
    check_out = models.DateTimeField(null=True, blank=True, verbose_name='Salida Registrada el')

    class Meta:
        verbose_name = 'Registro de Asistencia'
        verbose_name_plural = 'Registros de Asistencia'
        unique_together = ('session', 'student')

    def __str__(self):
        return f"{self.student.user.get_full_name()} - {self.session} ({self.status})"


class Justification(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pendiente'),
        ('approved', 'Aprobado'),
        ('rejected', 'Rechazado'),
    )

    attendance_record = models.OneToOneField(AttendanceRecord, on_delete=models.CASCADE, related_name='justification', verbose_name='Registro de Asistencia')
    reason = models.TextField(verbose_name='Motivo/Sustento')
    document_url = models.CharField(max_length=255, null=True, blank=True, verbose_name='URL del Documento Adjunto')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending', verbose_name='Estado')
    resolved_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='resolved_justifications', verbose_name='Resuelto por')
    resolved_at = models.DateTimeField(null=True, blank=True, verbose_name='Resuelto el')

    class Meta:
        verbose_name = 'Justificación de Inasistencia'
        verbose_name_plural = 'Justificaciones de Inasistencia'

    def __str__(self):
        return f"Justificación {self.id} - {self.attendance_record.student.user.get_full_name()}"


class AttendanceAuditLog(models.Model):
    ACTION_CHOICES = (
        ('create', 'Crear'),
        ('update', 'Modificar'),
        ('delete', 'Eliminar'),
    )

    attendance_record = models.ForeignKey(AttendanceRecord, on_delete=models.CASCADE, related_name='audit_logs', verbose_name='Registro de Asistencia')
    action = models.CharField(max_length=20, choices=ACTION_CHOICES, verbose_name='Acción')
    changed_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='attendance_audits', verbose_name='Usuario que modificó')
    old_status = models.CharField(max_length=20, choices=AttendanceRecord.STATUS_CHOICES, null=True, blank=True, verbose_name='Estado Anterior')
    new_status = models.CharField(max_length=20, choices=AttendanceRecord.STATUS_CHOICES, verbose_name='Estado Nuevo')
    reason = models.TextField(verbose_name='Razón de la modificación')
    timestamp = models.DateTimeField(auto_now_add=True, verbose_name='Fecha y Hora')

    class Meta:
        verbose_name = 'Auditoría de Asistencia'
        verbose_name_plural = 'Auditorías de Asistencias'
        ordering = ['-timestamp']

    def __str__(self):
        return f"Auditoría {self.id} - {self.attendance_record.student.user.get_full_name()} ({self.action})"


class AttendanceAlert(models.Model):
    STATUS_CHOICES = (
        ('green', 'Estable (Verde)'),
        ('yellow', 'Riesgo Moderado (Amarillo)'),
        ('red', 'Riesgo Alto (Rojo)'),
    )

    student = models.ForeignKey(StudentProfile, on_delete=models.CASCADE, related_name='alerts', verbose_name='Alumno')
    academic_period = models.ForeignKey(AcademicPeriod, on_delete=models.CASCADE, related_name='alerts', verbose_name='Periodo Académico')
    attendance_percentage = models.DecimalField(max_digits=5, decimal_places=2, verbose_name='Porcentaje de Asistencia')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, verbose_name='Semáforo de Asistencia')
    last_calculated = models.DateTimeField(auto_now=True, verbose_name='Último cálculo')

    class Meta:
        verbose_name = 'Alerta de Asistencia'
        verbose_name_plural = 'Alertas de Asistencia'
        unique_together = ('student', 'academic_period')

    def __str__(self):
        return f"Semáforo {self.student.user.get_full_name()} - {self.status} ({self.attendance_percentage}%)"
