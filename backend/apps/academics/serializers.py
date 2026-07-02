from rest_framework import serializers
from apps.users.serializers import UserSerializer, StudentProfileSerializer, TeacherProfileSerializer
from .models import Institution, Campus, Classroom, Program, AcademicPeriod, Course, Section, Enrollment


class InstitutionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Institution
        fields = '__all__'


class CampusSerializer(serializers.ModelSerializer):
    class Meta:
        model = Campus
        fields = '__all__'


class ClassroomSerializer(serializers.ModelSerializer):
    class Meta:
        model = Classroom
        fields = '__all__'


class ProgramSerializer(serializers.ModelSerializer):
    class Meta:
        model = Program
        fields = '__all__'


class AcademicPeriodSerializer(serializers.ModelSerializer):
    class Meta:
        model = AcademicPeriod
        fields = '__all__'


class CourseSerializer(serializers.ModelSerializer):
    program_name = serializers.CharField(source='program.name', read_only=True)

    class Meta:
        model = Course
        fields = ['id', 'program', 'program_name', 'name', 'code']


class SectionSerializer(serializers.ModelSerializer):
    course_detail = CourseSerializer(source='course', read_only=True)
    teacher_name = serializers.SerializerMethodField()

    class Meta:
        model = Section
        fields = ['id', 'course', 'course_detail', 'code', 'teacher', 'teacher_name', 'period']

    def get_teacher_name(self, obj):
        return obj.teacher.user.get_full_name()


class EnrollmentSerializer(serializers.ModelSerializer):
    student_detail = serializers.SerializerMethodField()
    section_detail = SectionSerializer(source='section', read_only=True)

    class Meta:
        model = Enrollment
        fields = ['id', 'student', 'student_detail', 'section', 'section_detail', 'enrolled_at']

    def get_student_detail(self, obj):
        return {
            'student_code': obj.student.student_code,
            'first_name': obj.student.user.first_name,
            'last_name': obj.student.user.last_name,
            'email': obj.student.user.email,
        }
