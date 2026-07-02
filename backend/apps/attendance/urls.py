from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    ClassSessionViewSet, AttendanceRecordViewSet, JustificationViewSet, 
    AttendanceAlertViewSet, AttendanceScanAPIView, AttendanceManualAPIView, 
    AttendanceJustifyAPIView, AttendanceCorrectAPIView
)

router = DefaultRouter()
router.register('sessions', ClassSessionViewSet, basename='session')
router.register('records', AttendanceRecordViewSet, basename='attendance-record')
router.register('justifications', JustificationViewSet, basename='justification')
router.register('alerts', AttendanceAlertViewSet, basename='attendance-alert')

urlpatterns = [
    # Router views
    path('', include(router.urls)),
    
    # Custom standalone views
    path('attendance/scan/', AttendanceScanAPIView.as_view(), name='attendance_scan'),
    path('attendance/manual/', AttendanceManualAPIView.as_view(), name='attendance_manual'),
    path('attendance/<int:pk>/justify/', AttendanceJustifyAPIView.as_view(), name='attendance_justify'),
    path('attendance/<int:pk>/correct/', AttendanceCorrectAPIView.as_view(), name='attendance_correct'),
]
