from django.contrib import admin
from django.urls import path, include
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView

urlpatterns = [
    path('admin/', admin.site.site_urls if hasattr(admin.site, 'site_urls') else admin.site.urls),
    
    # API Documentation
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/swagger/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/docs/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
    
    # App routers and URL endpoints
    path('api/v1/auth/', include('apps.users.urls')),
    path('api/v1/', include('apps.academics.urls')),
    path('api/v1/', include('apps.attendance.urls')),
    path('api/v1/reports/', include('apps.reports.urls')),
]
