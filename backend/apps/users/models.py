import uuid
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models


class UserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('El email es obligatorio')
        email = self.normalize_email(email)
        # Use email as username
        extra_fields.setdefault('username', email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('role', 'superadmin')
        return self.create_user(email, password, **extra_fields)


class User(AbstractUser):
    ROLE_CHOICES = (
        ('superadmin', 'Super Administrador'),
        ('admin', 'Administrador Institucional'),
        ('teacher', 'Docente'),
        ('student', 'Alumno'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True, verbose_name='Correo Electrónico')
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='student', verbose_name='Rol')
    avatar = models.TextField(null=True, blank=True, verbose_name='Foto de Perfil (Base64)')
    
    # We use email as the login identifier
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = []

    objects = UserManager()

    class Meta:
        verbose_name = 'Usuario'
        verbose_name_plural = 'Usuarios'

    def __str__(self):
        return f"{self.get_full_name()} ({self.role})"


class StudentProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='student_profile')
    student_code = models.CharField(max_length=20, unique=True, verbose_name='Código de Alumno')

    class Meta:
        verbose_name = 'Perfil de Alumno'
        verbose_name_plural = 'Perfiles de Alumnos'

    def __str__(self):
        return f"{self.user.get_full_name()} - {self.student_code}"


class TeacherProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='teacher_profile')
    teacher_code = models.CharField(max_length=20, unique=True, verbose_name='Código de Docente')

    class Meta:
        verbose_name = 'Perfil de Docente'
        verbose_name_plural = 'Perfiles de Docentes'

    def __str__(self):
        return f"{self.user.get_full_name()} - {self.teacher_code}"
