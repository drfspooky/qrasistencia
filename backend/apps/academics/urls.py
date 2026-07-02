from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    InstitutionViewSet, CampusViewSet, ClassroomViewSet, 
    ProgramViewSet, AcademicPeriodViewSet, CourseViewSet, 
    SectionViewSet, EnrollmentViewSet
)

router = DefaultRouter()
router.register('institutions', InstitutionViewSet, basename='institution')
router.register('campuses', CampusViewSet, basename='campus')
router.register('classrooms', ClassroomViewSet, basename='classroom')
router.register('programs', ProgramViewSet, basename='program')
router.register('periods', AcademicPeriodViewSet, basename='period')
router.register('courses', CourseViewSet, basename='course')
router.register('sections', SectionViewSet, basename='section')
router.register('enrollments', EnrollmentViewSet, basename='enrollment')

urlpatterns = [
    path('', include(router.urls)),
]
