from django.contrib import admin
from .models import ClassSession, SessionQRCode, AttendanceRecord, Justification, AttendanceAuditLog, AttendanceAlert

class SessionQRCodeInline(admin.TabularInline):
    model = SessionQRCode
    extra = 0
    readonly_fields = ('created_at',)

class AttendanceRecordInline(admin.TabularInline):
    model = AttendanceRecord
    extra = 0
    readonly_fields = ('recorded_at', 'recorded_by', 'geo_valid', 'latitude', 'longitude')

@admin.register(ClassSession)
class ClassSessionAdmin(admin.ModelAdmin):
    list_display = ('get_course_name', 'section', 'classroom', 'date', 'start_time', 'end_time', 'status')
    list_filter = ('status', 'date', 'section__course', 'classroom')
    search_fields = ('section__code', 'section__course__name', 'classroom__name')
    date_hierarchy = 'date'
    inlines = [SessionQRCodeInline, AttendanceRecordInline]

    def get_course_name(self, obj):
        return obj.section.course.name
    get_course_name.short_description = 'Curso'

@admin.register(SessionQRCode)
class SessionQRCodeAdmin(admin.ModelAdmin):
    list_display = ('code', 'session', 'created_at', 'expires_at', 'is_active')
    list_filter = ('is_active', 'created_at')
    search_fields = ('code', 'session__section__course__name')

@admin.register(AttendanceRecord)
class AttendanceRecordAdmin(admin.ModelAdmin):
    list_display = ('student', 'get_course_name', 'session_date', 'status', 'recorded_at', 'recorded_by', 'geo_valid')
    list_filter = ('status', 'recorded_by', 'geo_valid', 'session__date', 'session__section__course')
    search_fields = ('student__student_code', 'student__user__first_name', 'student__user__last_name', 'session__section__course__name')
    readonly_fields = ('recorded_at', 'recorded_by', 'latitude', 'longitude', 'geo_valid', 'check_out')

    def get_course_name(self, obj):
        return obj.session.section.course.name
    get_course_name.short_description = 'Curso'

    def session_date(self, obj):
        return obj.session.date
    session_date.short_description = 'Fecha Sesión'

@admin.register(Justification)
class JustificationAdmin(admin.ModelAdmin):
    list_display = ('id', 'get_student_name', 'get_course_name', 'get_session_date', 'status', 'resolved_by', 'resolved_at')
    list_filter = ('status', 'resolved_at')
    search_fields = (
        'attendance_record__student__student_code', 
        'attendance_record__student__user__first_name', 
        'attendance_record__student__user__last_name',
        'reason'
    )
    readonly_fields = ('attendance_record', 'reason', 'document_url')

    def get_student_name(self, obj):
        return obj.attendance_record.student.user.get_full_name()
    get_student_name.short_description = 'Alumno'

    def get_course_name(self, obj):
        return obj.attendance_record.session.section.course.name
    get_course_name.short_description = 'Curso'

    def get_session_date(self, obj):
        return obj.attendance_record.session.date
    get_session_date.short_description = 'Fecha Clase'

@admin.register(AttendanceAuditLog)
class AttendanceAuditLogAdmin(admin.ModelAdmin):
    list_display = ('attendance_record', 'action', 'changed_by', 'old_status', 'new_status', 'timestamp')
    list_filter = ('action', 'timestamp')
    search_fields = (
        'attendance_record__student__student_code',
        'attendance_record__student__user__first_name',
        'attendance_record__student__user__last_name',
        'reason'
    )
    readonly_fields = ('attendance_record', 'action', 'changed_by', 'old_status', 'new_status', 'reason', 'timestamp')

@admin.register(AttendanceAlert)
class AttendanceAlertAdmin(admin.ModelAdmin):
    list_display = ('student', 'academic_period', 'attendance_percentage', 'status', 'last_calculated')
    list_filter = ('status', 'academic_period')
    search_fields = ('student__student_code', 'student__user__first_name', 'student__user__last_name')
    readonly_fields = ('student', 'academic_period', 'attendance_percentage', 'status', 'last_calculated')
