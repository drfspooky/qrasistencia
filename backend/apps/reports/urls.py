from django.urls import path
from .views import (
    DailySummaryAPIView, ByStudentReportAPIView, ByCourseReportAPIView,
    ExportPDFReportAPIView, ExportExcelReportAPIView
)

urlpatterns = [
    path('daily/', DailySummaryAPIView.as_view(), name='reports_daily'),
    path('by-student/', ByStudentReportAPIView.as_view(), name='reports_by_student'),
    path('by-course/', ByCourseReportAPIView.as_view(), name='reports_by_course'),
    path('export/pdf/', ExportPDFReportAPIView.as_view(), name='reports_export_pdf'),
    path('export/excel/', ExportExcelReportAPIView.as_view(), name='reports_export_excel'),
]
