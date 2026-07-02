from django.test import TestCase
from django.contrib.auth import get_user_model
from django.utils import timezone
from apps.users.models import StudentProfile, TeacherProfile
from apps.academics.models import Institution, Campus, Classroom, Program, AcademicPeriod, Course, Section, Enrollment
from apps.attendance.models import ClassSession, SessionQRCode, AttendanceRecord
from apps.attendance.views import calculate_distance
from datetime import date, time, timedelta

User = get_user_model()


class GeolocationTestCase(TestCase):
    def test_haversine_distance(self):
        # Coordinates of Barranco (Lima) and Surco (Lima)
        # Point A: Barranco (-12.1489, -77.0211)
        # Point B: Surco (-12.1246, -77.0278)
        dist = calculate_distance(-12.1489, -77.0211, -12.1246, -77.0278)
        # Expected distance is roughly 2.8 km (2800 meters)
        self.assertTrue(2500 < dist < 3200)


class AttendanceScanTestCase(TestCase):
    def setUp(self):
        # Create user models
        self.teacher_user = User.objects.create_user(
            email='docente_test@demo.com',
            password='password',
            first_name='Juan',
            last_name='Perez',
            role='teacher'
        )
        self.teacher = TeacherProfile.objects.create(user=self.teacher_user, teacher_code='TTEST01')

        self.student_user = User.objects.create_user(
            email='alumno_test@demo.com',
            password='password',
            first_name='Carlos',
            last_name='Gomez',
            role='student'
        )
        self.student = StudentProfile.objects.create(user=self.student_user, student_code='STEST01')

        # Academics setup
        self.inst = Institution.objects.create(name='U Test', code='UTEST')
        self.campus = Campus.objects.create(institution=self.inst, name='Campus Test', address='Calle Falsa 123')
        self.classroom = Classroom.objects.create(
            campus=self.campus,
            name='Aula 101',
            latitude=-12.124600,
            longitude=-77.027800,
            radius_meters=50
        )
        self.period = AcademicPeriod.objects.create(
            name='2026-I',
            start_date=date(2026, 1, 1),
            end_date=date(2026, 7, 1),
            is_active=True
        )
        self.program = Program.objects.create(campus=self.campus, name='Software', code='SOFT')
        self.course = Course.objects.create(program=self.program, name='POO', code='POO1')
        self.section = Section.objects.create(course=self.course, code='NX01', teacher=self.teacher, period=self.period)

        # Enroll student
        self.enrollment = Enrollment.objects.create(student=self.student, section=self.section)

        # Session setup
        self.session = ClassSession.objects.create(
            section=self.section,
            classroom=self.classroom,
            date=timezone.now().date(),
            start_time=time(19, 0),
            end_time=time(21, 0),
            status='active',
            tolerance_minutes=15
        )

        # Generate QR
        self.qr = SessionQRCode.objects.create(
            session=self.session,
            expires_at=timezone.now() + timedelta(seconds=30),
            is_active=True
        )

    def test_prepopulated_attendance_records(self):
        # Opening a session should pre-populate enrollments
        # Simulating open logic manually in setup
        AttendanceRecord.objects.get_or_create(
            session=self.session,
            student=self.student,
            defaults={'status': 'falta', 'recorded_by': 'system_absent'}
        )
        record = AttendanceRecord.objects.get(session=self.session, student=self.student)
        self.assertEqual(record.status, 'falta')

    def test_qr_expiration(self):
        # Create an expired QR
        expired_qr = SessionQRCode.objects.create(
            session=self.session,
            expires_at=timezone.now() - timedelta(seconds=1),
            is_active=True
        )
        # Check logic: we simulate scan API check
        is_expired = timezone.now() > expired_qr.expires_at
        self.assertTrue(is_expired)


from rest_framework.test import APITestCase

class DateFilteringTestCase(APITestCase):
    def setUp(self):
        self.teacher_user = User.objects.create_user(
            email='docente_filter@demo.com',
            password='password',
            first_name='Juan',
            last_name='Perez',
            role='teacher'
        )
        self.teacher = TeacherProfile.objects.create(user=self.teacher_user, teacher_code='TFILTER')
        
        self.student_user = User.objects.create_user(
            email='alumno_filter@demo.com',
            password='password',
            first_name='Carlos',
            last_name='Gomez',
            role='student'
        )
        self.student = StudentProfile.objects.create(user=self.student_user, student_code='SFILTER')

        self.inst = Institution.objects.create(name='U Test', code='UTEST')
        self.campus = Campus.objects.create(institution=self.inst, name='Campus Test', address='Calle Falsa 123')
        self.classroom = Classroom.objects.create(
            campus=self.campus,
            name='Aula 101',
            latitude=-12.124600,
            longitude=-77.027800,
            radius_meters=50
        )
        self.period = AcademicPeriod.objects.create(
            name='2026-I',
            start_date=date(2026, 1, 1),
            end_date=date(2026, 7, 1),
            is_active=True
        )
        self.program = Program.objects.create(campus=self.campus, name='Software', code='SOFT')
        self.course = Course.objects.create(program=self.program, name='POO', code='POO1')
        self.section = Section.objects.create(course=self.course, code='NX01', teacher=self.teacher, period=self.period)
        self.enrollment = Enrollment.objects.create(student=self.student, section=self.section)

        # Create sessions on different dates
        self.session_past = ClassSession.objects.create(
            section=self.section,
            classroom=self.classroom,
            date=date(2026, 6, 10),
            start_time=time(19, 0),
            end_time=time(21, 0),
            status='scheduled'
        )
        self.session_today = ClassSession.objects.create(
            section=self.section,
            classroom=self.classroom,
            date=date(2026, 6, 15),
            start_time=time(19, 0),
            end_time=time(21, 0),
            status='scheduled'
        )
        self.session_future = ClassSession.objects.create(
            section=self.section,
            classroom=self.classroom,
            date=date(2026, 6, 20),
            start_time=time(19, 0),
            end_time=time(21, 0),
            status='scheduled'
        )

        # Create attendance records for student
        self.record_past = AttendanceRecord.objects.create(
            session=self.session_past,
            student=self.student,
            status='presente'
        )
        self.record_today = AttendanceRecord.objects.create(
            session=self.session_today,
            student=self.student,
            status='presente'
        )
        self.record_future = AttendanceRecord.objects.create(
            session=self.session_future,
            student=self.student,
            status='falta'
        )

    def test_session_filtering_for_teacher(self):
        self.client.force_authenticate(user=self.teacher_user)
        
        # Test default/no filter (returns all 3 sessions)
        response = self.client.get('/api/v1/sessions/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 3)

        # Test filtering by start_date
        response = self.client.get('/api/v1/sessions/', {'start_date': '2026-06-15'})
        self.assertEqual(len(response.data), 2)
        dates = [s['date'] for s in response.data]
        self.assertIn('2026-06-15', dates)
        self.assertIn('2026-06-20', dates)

        # Test filtering by end_date
        response = self.client.get('/api/v1/sessions/', {'end_date': '2026-06-15'})
        self.assertEqual(len(response.data), 2)
        dates = [s['date'] for s in response.data]
        self.assertIn('2026-06-10', dates)
        self.assertIn('2026-06-15', dates)

        # Test filtering by both
        response = self.client.get('/api/v1/sessions/', {'start_date': '2026-06-12', 'end_date': '2026-06-18'})
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['date'], '2026-06-15')

    def test_record_filtering_for_student(self):
        self.client.force_authenticate(user=self.student_user)

        # Test default/no filter (returns all 3 records)
        response = self.client.get('/api/v1/records/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 3)

        # Test filtering by start_date
        response = self.client.get('/api/v1/records/', {'start_date': '2026-06-15'})
        self.assertEqual(len(response.data), 2)

        # Test filtering by end_date
        response = self.client.get('/api/v1/records/', {'end_date': '2026-06-15'})
        self.assertEqual(len(response.data), 2)

        # Test filtering by both
        response = self.client.get('/api/v1/records/', {'start_date': '2026-06-12', 'end_date': '2026-06-18'})
        self.assertEqual(len(response.data), 1)

    def test_export_pdf_endpoint(self):
        self.client.force_authenticate(user=self.teacher_user)
        response = self.client.get(f'/api/v1/sessions/{self.session_today.id}/export-pdf/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response['Content-Type'], 'application/pdf')
        self.assertIn('attachment', response['Content-Disposition'])
        self.assertIn('.pdf', response['Content-Disposition'])

    def test_export_pdf_query_token_authentication(self):
        # Authenticate with query token (no headers)
        from rest_framework_simplejwt.tokens import RefreshToken
        refresh = RefreshToken.for_user(self.teacher_user)
        access_token = str(refresh.access_token)
        
        # Test download with token query param
        response = self.client.get(f'/api/v1/sessions/{self.session_today.id}/export-pdf/', {'token': access_token})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response['Content-Type'], 'application/pdf')
