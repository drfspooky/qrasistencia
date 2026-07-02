from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User, StudentProfile, TeacherProfile

class StudentProfileInline(admin.StackedInline):
    model = StudentProfile
    can_delete = False
    verbose_name_plural = 'Perfil de Alumno'

class TeacherProfileInline(admin.StackedInline):
    model = TeacherProfile
    can_delete = False
    verbose_name_plural = 'Perfil de Docente'

class CustomUserAdmin(UserAdmin):
    model = User
    list_display = ('email', 'first_name', 'last_name', 'role', 'is_staff', 'is_superuser', 'is_active')
    list_filter = ('role', 'is_staff', 'is_superuser', 'is_active')
    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Información Personal', {'fields': ('first_name', 'last_name', 'avatar')}),
        ('Permisos', {'fields': ('role', 'is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Fechas Importantes', {'fields': ('last_login', 'date_joined')}),
    )
    search_fields = ('email', 'first_name', 'last_name')
    ordering = ('email',)
    inlines = []

    def get_inlines(self, request, obj=None):
        if obj:
            if obj.role == 'student':
                return [StudentProfileInline]
            elif obj.role == 'teacher':
                return [TeacherProfileInline]
        return []

admin.site.register(User, CustomUserAdmin)

@admin.register(StudentProfile)
class StudentProfileAdmin(admin.ModelAdmin):
    list_display = ('student_code', 'get_full_name', 'email')
    search_fields = ('student_code', 'user__first_name', 'user__last_name', 'user__email')
    
    def get_full_name(self, obj):
        return obj.user.get_full_name()
    get_full_name.short_description = 'Nombre Completo'
    
    def email(self, obj):
        return obj.user.email
    email.short_description = 'Correo'

@admin.register(TeacherProfile)
class TeacherProfileAdmin(admin.ModelAdmin):
    list_display = ('teacher_code', 'get_full_name', 'email')
    search_fields = ('teacher_code', 'user__first_name', 'user__last_name', 'user__email')
    
    def get_full_name(self, obj):
        return obj.user.get_full_name()
    get_full_name.short_description = 'Nombre Completo'
    
    def email(self, obj):
        return obj.user.email
    email.short_description = 'Correo'
