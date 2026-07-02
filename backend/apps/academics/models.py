from django.db import models
from apps.users.models import StudentProfile, TeacherProfile


class Institution(models.Model):
    name = models.CharField(max_length=100, verbose_name='Nombre')
    code = models.CharField(max_length=20, unique=True, verbose_name='Código')
    logo = models.ImageField(upload_to='institutions/logos/', null=True, blank=True, verbose_name='Logo')

    class Meta:
        verbose_name = 'Institución'
        verbose_name_plural = 'Instituciones'

    def __str__(self):
        return self.name


class Campus(models.Model):
    institution = models.ForeignKey(Institution, on_delete=models.CASCADE, related_name='campuses', verbose_name='Institución')
    name = models.CharField(max_length=100, verbose_name='Nombre')
    address = models.CharField(max_length=200, verbose_name='Dirección')

    class Meta:
        verbose_name = 'Campus'
        verbose_name_plural = 'Campuses'

    def __str__(self):
        return f"{self.name} - {self.institution.name}"


class Classroom(models.Model):
    campus = models.ForeignKey(Campus, on_delete=models.CASCADE, related_name='classrooms', verbose_name='Campus')
    name = models.CharField(max_length=50, verbose_name='Nombre/Pabellón/Aula')
    latitude = models.DecimalField(max_digits=9, decimal_places=6, verbose_name='Latitud')
    longitude = models.DecimalField(max_digits=9, decimal_places=6, verbose_name='Longitud')
    radius_meters = models.IntegerField(default=50, verbose_name='Radio de tolerancia (metros)')

    class Meta:
        verbose_name = 'Aula'
        verbose_name_plural = 'Aulas'

    def __str__(self):
        return f"{self.name} ({self.campus.name})"


class Program(models.Model):
    campus = models.ForeignKey(Campus, on_delete=models.CASCADE, related_name='programs', verbose_name='Campus')
    name = models.CharField(max_length=100, verbose_name='Nombre de Carrera/Programa')
    code = models.CharField(max_length=20, unique=True, verbose_name='Código de Carrera')

    class Meta:
        verbose_name = 'Programa/Carrera'
        verbose_name_plural = 'Programas/Carreras'

    def __str__(self):
        return self.name


class AcademicPeriod(models.Model):
    name = models.CharField(max_length=20, unique=True, verbose_name='Periodo Académico')
    start_date = models.DateField(verbose_name='Fecha de Inicio')
    end_date = models.DateField(verbose_name='Fecha de Fin')
    is_active = models.BooleanField(default=False, verbose_name='Periodo Activo')

    class Meta:
        verbose_name = 'Periodo Académico'
        verbose_name_plural = 'Periodos Académicos'

    def __str__(self):
        return self.name


class Course(models.Model):
    program = models.ForeignKey(Program, on_delete=models.CASCADE, related_name='courses', verbose_name='Carrera/Programa')
    name = models.CharField(max_length=100, verbose_name='Nombre de Curso')
    code = models.CharField(max_length=20, unique=True, verbose_name='Código de Curso')

    class Meta:
        verbose_name = 'Curso'
        verbose_name_plural = 'Cursos'

    def __str__(self):
        return f"{self.name} ({self.code})"


class Section(models.Model):
    course = models.ForeignKey(Course, on_delete=models.CASCADE, related_name='sections', verbose_name='Curso')
    code = models.CharField(max_length=20, verbose_name='Sección')
    teacher = models.ForeignKey(TeacherProfile, on_delete=models.CASCADE, related_name='sections', verbose_name='Docente')
    period = models.ForeignKey(AcademicPeriod, on_delete=models.CASCADE, related_name='sections', verbose_name='Periodo Académico')

    class Meta:
        verbose_name = 'Sección'
        verbose_name_plural = 'Secciones'
        unique_together = ('course', 'code', 'period')

    def __str__(self):
        return f"{self.course.code} - {self.code} ({self.period.name})"


class Enrollment(models.Model):
    student = models.ForeignKey(StudentProfile, on_delete=models.CASCADE, related_name='enrollments', verbose_name='Alumno')
    section = models.ForeignKey(Section, on_delete=models.CASCADE, related_name='enrollments', verbose_name='Sección')
    enrolled_at = models.DateTimeField(auto_now_add=True, verbose_name='Fecha de Matrícula')

    class Meta:
        verbose_name = 'Matrícula/Inscripción'
        verbose_name_plural = 'Matrículas/Inscripciones'
        unique_together = ('student', 'section')

    def __str__(self):
        return f"{self.student.user.get_full_name()} matriculado en {self.section}"
