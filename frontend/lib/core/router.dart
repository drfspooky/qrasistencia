import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_provider.dart';
import '../features/auth/login_page.dart';
import '../features/auth/splash_page.dart';
import '../features/auth/settings_page.dart';
import '../features/student/student_dashboard.dart';
import '../features/student/student_scanner.dart';
import '../features/student/student_history.dart';
import '../features/teacher/teacher_dashboard.dart';
import '../features/teacher/teacher_session_detail.dart';
import '../features/admin/admin_dashboard.dart';

/// A notifier that listens to Riverpod's authProvider and alerts GoRouter on state changes.
class RouterTransitionNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterTransitionNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (previous, next) {
      print("[Router] AuthState changed (isLoading: ${next.isLoading}, isAuthenticated: ${next.isAuthenticated}). Notifying router...");
      notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = RouterTransitionNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: listenable,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      // Dashboards
      GoRoute(
        path: '/',
        builder: (context, state) {
          final authState = ref.read(authProvider);
          if (!authState.isAuthenticated || authState.user == null) {
            return const LoginPage();
          }
          final role = authState.user!['role'];
          if (role == 'student') {
            return const StudentDashboard();
          } else if (role == 'teacher') {
            return const TeacherDashboard();
          } else {
            return const AdminDashboard();
          }
        },
      ),
      // Student Specific Routes
      GoRoute(
        path: '/student/scan',
        builder: (context, state) => const StudentScannerPage(),
      ),
      GoRoute(
        path: '/student/history',
        builder: (context, state) => const StudentHistoryPage(),
      ),
      // Teacher Specific Routes
      GoRoute(
        path: '/teacher/session/:id',
        builder: (context, state) {
          final idStr = state.pathParameters['id']!;
          final sessionId = int.parse(idStr);
          return TeacherSessionDetailPage(sessionId: sessionId);
        },
      ),
      // Settings Route
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isSplash = state.matchedLocation == '/splash';
      final isLoggingIn = state.matchedLocation == '/login';

      print("[Router] Redirect check - Location: ${state.matchedLocation}, isLoading: ${authState.isLoading}, isAuthenticated: ${authState.isAuthenticated}");

      if (authState.isLoading) {
        print("[Router] Keeping on splash (loading session)");
        return isSplash ? null : '/splash';
      }

      if (!authState.isAuthenticated) {
        if (isLoggingIn) {
          print("[Router] Keeping on login");
          return null;
        }
        print("[Router] Redirecting from ${state.matchedLocation} to /login");
        return '/login';
      }

      // If authenticated and on login/splash, redirect to home
      if (isLoggingIn || isSplash) {
        print("[Router] Redirecting authenticated user to /");
        return '/';
      }

      print("[Router] No redirection needed");
      return null;
    },
  );
});
