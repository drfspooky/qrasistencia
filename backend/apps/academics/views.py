from rest_framework import viewsets, permissions
from apps.users.permissions import IsAdminOrReadOnly, IsAdmin
from .models import Institution, Campus, Classroom, Program, AcademicPeriod, Course, Section, Enrollment
from .serializers import (
    InstitutionSerializer, CampusSerializer, ClassroomSerializer, 
    ProgramSerializer, AcademicPeriodSerializer, CourseSerializer, 
    SectionSerializer, EnrollmentSerializer
)


class InstitutionViewSet(viewsets.ModelViewSet):
    queryset = Institution.objects.all()
    serializer_class = InstitutionSerializer
    permission_classes = [IsAdminOrReadOnly]


class CampusViewSet(viewsets.ModelViewSet):
    queryset = Campus.objects.all()
    serializer_class = CampusSerializer
    permission_classes = [IsAdminOrReadOnly]


class ClassroomViewSet(viewsets.ModelViewSet):
    queryset = Classroom.objects.all()
    serializer_class = ClassroomSerializer
    permission_classes = [IsAdminOrReadOnly]


class ProgramViewSet(viewsets.ModelViewSet):
    queryset = Program.objects.all()
    serializer_class = ProgramSerializer
    permission_classes = [IsAdminOrReadOnly]


class AcademicPeriodViewSet(viewsets.ModelViewSet):
    queryset = AcademicPeriod.objects.all()
    serializer_class = AcademicPeriodSerializer
    permission_classes = [IsAdminOrReadOnly]


class CourseViewSet(viewsets.ModelViewSet):
    queryset = Course.objects.all()
    serializer_class = CourseSerializer
    permission_classes = [IsAdminOrReadOnly]


class SectionViewSet(viewsets.ModelViewSet):
    serializer_class = SectionSerializer
    permission_classes = [IsAdminOrReadOnly]

    def get_queryset(self):
        user = self.request.user
        if not user.is_authenticated:
            return Section.objects.none()
            
        if user.role in ['superadmin', 'admin']:
            return Section.objects.all().select_related('course', 'teacher__user', 'period')
        elif user.role == 'teacher':
            return Section.objects.filter(teacher__user=user).select_related('course', 'teacher__user', 'period')
        elif user.role == 'student':
            return Section.objects.filter(enrollments__student__user=user).select_related('course', 'teacher__user', 'period')
        return Section.objects.none()


class EnrollmentViewSet(viewsets.ModelViewSet):
    serializer_class = EnrollmentSerializer
    permission_classes = [IsAdmin]  # Only admins can enroll students manually

    def get_queryset(self):
        user = self.request.user
        if not user.is_authenticated:
            return Enrollment.objects.none()

        if user.role in ['superadmin', 'admin']:
            return Enrollment.objects.all().select_related('student__user', 'section__course', 'section__teacher__user')
        elif user.role == 'teacher':
            return Enrollment.objects.filter(section__teacher__user=user).select_related('student__user', 'section__course', 'section__teacher__user')
        elif user.role == 'student':
            return Enrollment.objects.filter(student__user=user).select_related('student__user', 'section__course', 'section__teacher__user')
        return Enrollment.objects.none()
