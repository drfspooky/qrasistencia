from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model
from .models import StudentProfile, TeacherProfile

User = get_user_model()


class StudentProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = StudentProfile
        fields = ['student_code']


class TeacherProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = TeacherProfile
        fields = ['teacher_code']


class UserSerializer(serializers.ModelSerializer):
    student_profile = StudentProfileSerializer(read_only=True)
    teacher_profile = TeacherProfileSerializer(read_only=True)

    class Meta:
        model = User
        fields = ['id', 'email', 'first_name', 'last_name', 'role', 'avatar', 'student_profile', 'teacher_profile']
        read_only_fields = ['id', 'role']


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['role'] = user.role
        token['email'] = user.email
        token['first_name'] = user.first_name
        token['last_name'] = user.last_name
        token['avatar'] = user.avatar
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        user = self.user
        
        # Build user payload to return in login response
        user_data = {
            'id': str(user.id),
            'email': user.email,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'role': user.role,
            'avatar': user.avatar,
        }
        
        if user.role == 'student' and hasattr(user, 'student_profile'):
            user_data['student_code'] = user.student_profile.student_code
            user_data['student_profile_id'] = user.student_profile.id
        elif user.role == 'teacher' and hasattr(user, 'teacher_profile'):
            user_data['teacher_code'] = user.teacher_profile.teacher_code
            user_data['teacher_profile_id'] = user.teacher_profile.id
            
        data['user'] = user_data
        return data
