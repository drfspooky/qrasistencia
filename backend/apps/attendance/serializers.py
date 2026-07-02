from rest_framework import serializers
from apps.users.serializers import UserSerializer
from apps.academics.serializers import SectionSerializer, ClassroomSerializer
from .models import ClassSession, SessionQRCode, AttendanceRecord, Justification, AttendanceAuditLog, AttendanceAlert


class ClassSessionSerializer(serializers.ModelSerializer):
    section_detail = SectionSerializer(source='section', read_only=True)
    classroom_detail = ClassroomSerializer(source='classroom', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = ClassSession
        fields = ['id', 'section', 'section_detail', 'classroom', 'classroom_detail', 'date', 'start_time', 'end_time', 'status', 'status_display', 'tolerance_minutes']


class SessionQRCodeSerializer(serializers.ModelSerializer):
    class Meta:
        model = SessionQRCode
        fields = ['id', 'session', 'code', 'created_at', 'expires_at', 'is_active']


class AttendanceRecordSerializer(serializers.ModelSerializer):
    student_name = serializers.SerializerMethodField()
    student_code = serializers.CharField(source='student.student_code', read_only=True)
    session_detail = ClassSessionSerializer(source='session', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    recorded_by_display = serializers.CharField(source='get_recorded_by_display', read_only=True)
    justification_status = serializers.SerializerMethodField()

    class Meta:
        model = AttendanceRecord
        fields = [
            'id', 'session', 'session_detail', 'student', 'student_name', 'student_code', 
            'status', 'status_display', 'recorded_at', 'recorded_by', 'recorded_by_display', 
            'latitude', 'longitude', 'geo_valid', 'check_out', 'justification_status'
        ]
        read_only_fields = ['id', 'recorded_at', 'recorded_by', 'geo_valid', 'check_out']

    def get_student_name(self, obj):
        return obj.student.user.get_full_name()

    def get_justification_status(self, obj):
        return obj.justification.status if hasattr(obj, 'justification') else None


class JustificationSerializer(serializers.ModelSerializer):
    resolved_by_detail = UserSerializer(source='resolved_by', read_only=True)
    attendance_detail = AttendanceRecordSerializer(source='attendance_record', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = Justification
        fields = ['id', 'attendance_record', 'attendance_detail', 'reason', 'document_url', 'status', 'status_display', 'resolved_by', 'resolved_by_detail', 'resolved_at']
        read_only_fields = ['id', 'status', 'resolved_by', 'resolved_at']


class AttendanceAuditLogSerializer(serializers.ModelSerializer):
    changed_by_name = serializers.SerializerMethodField()

    class Meta:
        model = AttendanceAuditLog
        fields = ['id', 'attendance_record', 'action', 'changed_by', 'changed_by_name', 'old_status', 'new_status', 'reason', 'timestamp']

    def get_changed_by_name(self, obj):
        return obj.changed_by.get_full_name()


class AttendanceAlertSerializer(serializers.ModelSerializer):
    student_name = serializers.SerializerMethodField()
    student_code = serializers.CharField(source='student.student_code', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = AttendanceAlert
        fields = ['id', 'student', 'student_name', 'student_code', 'academic_period', 'attendance_percentage', 'status', 'status_display', 'last_calculated']

    def get_student_name(self, obj):
        return obj.student.user.get_full_name()


class AttendanceScanRequestSerializer(serializers.Serializer):
    qr_code = serializers.CharField(required=True, help_text="Código del token QR")
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6, required=False, allow_null=True)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6, required=False, allow_null=True)


class AttendanceManualRequestSerializer(serializers.Serializer):
    attendance_id = serializers.IntegerField(required=True)
    status = serializers.ChoiceField(choices=AttendanceRecord.STATUS_CHOICES, required=True)
    reason = serializers.CharField(required=True)


class AttendanceJustifyRequestSerializer(serializers.Serializer):
    attendance_id = serializers.IntegerField(required=False, allow_null=True)
    reason = serializers.CharField(required=True)
    document_url = serializers.CharField(required=False, allow_blank=True, default='')


class AttendanceCorrectRequestSerializer(serializers.Serializer):
    justification_id = serializers.IntegerField(required=False, allow_null=True)
    status = serializers.ChoiceField(choices=Justification.STATUS_CHOICES, required=True)
    override_status = serializers.ChoiceField(choices=AttendanceRecord.STATUS_CHOICES, required=False, allow_null=True)
    reason = serializers.CharField(required=True)

