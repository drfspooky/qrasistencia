from django.contrib import admin
from .models import Institution, Campus, Classroom, Program, AcademicPeriod, Course, Section, Enrollment

@admin.register(Institution)
class InstitutionAdmin(admin.ModelAdmin):
    list_display = ('name', 'code')
    search_fields = ('name', 'code')

@admin.register(Campus)
class CampusAdmin(admin.ModelAdmin):
    list_display = ('name', 'address', 'institution')
    list_filter = ('institution',)
    search_fields = ('name', 'address')

@admin.register(Classroom)
class ClassroomAdmin(admin.ModelAdmin):
    list_display = ('name', 'campus', 'latitude', 'longitude', 'radius_meters')
    list_filter = ('campus',)
    search_fields = ('name',)

@admin.register(Program)
class ProgramAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'campus')
    list_filter = ('campus',)
    search_fields = ('name', 'code')

@admin.register(AcademicPeriod)
class AcademicPeriodAdmin(admin.ModelAdmin):
    list_display = ('name', 'start_date', 'end_date', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('name',)

@admin.register(Course)
class CourseAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'program')
    list_filter = ('program',)
    search_fields = ('name', 'code')

class EnrollmentInline(admin.TabularInline):
    model = Enrollment
    extra = 1

@admin.register(Section)
class SectionAdmin(admin.ModelAdmin):
    list_display = ('get_course_code', 'course', 'code', 'teacher', 'period')
    list_filter = ('period', 'course', 'teacher')
    search_fields = ('code', 'course__name', 'course__code', 'teacher__user__first_name', 'teacher__user__last_name')
    inlines = [EnrollmentInline]

    def get_course_code(self, obj):
        return obj.course.code
    get_course_code.short_description = 'Cód. Curso'

@admin.register(Enrollment)
class EnrollmentAdmin(admin.ModelAdmin):
    list_display = ('student', 'section', 'enrolled_at')
    list_filter = ('section__period', 'section__course')
    search_fields = ('student__student_code', 'student__user__first_name', 'student__user__last_name', 'section__code', 'section__course__name')
