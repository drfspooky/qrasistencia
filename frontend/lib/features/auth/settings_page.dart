import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/auth_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = true;
  bool _isUploadingAvatar = false;

  // Stats / KPI data
  bool _isLoadingStats = false;
  double _avgAttendance = 0.0;
  int _totalCoursesOrSessions = 0;
  int _totalTeacherCourses = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchKPIs();
    });
  }

  Future<void> _fetchKPIs() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) return;
    final role = user['role'] ?? 'student';

    setState(() {
      _isLoadingStats = true;
    });

    try {
      final client = ref.read(authProvider.notifier).apiClient;
      if (role == 'student') {
        final response = await client.get('/api/v1/reports/by-student/');
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final courses = data['courses'] as List? ?? [];
          double total = 0.0;
          for (var course in courses) {
            total += (course['attendance_percentage'] as num).toDouble();
          }
          if (mounted) {
            setState(() {
              _avgAttendance = courses.isNotEmpty
                  ? double.parse((total / courses.length).toStringAsFixed(1))
                  : 0.0;
              _totalCoursesOrSessions = courses.length;
            });
          }
        }
      } else if (role == 'teacher') {
        final response = await client.get('/api/v1/sessions/');
        if (response.statusCode == 200) {
          final List sessions = jsonDecode(response.body);
          final uniqueCourses = <String>{};
          for (var session in sessions) {
            if (session['course_name'] != null) {
              uniqueCourses.add(session['course_name'].toString());
            }
          }
          if (mounted) {
            setState(() {
              _totalTeacherCourses = uniqueCourses.length;
              _totalCoursesOrSessions = sessions.length;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading stats in SettingsPage: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 75,
      );

      if (pickedFile == null) return;

      setState(() {
        _isUploadingAvatar = true;
      });

      final fileBytes = await pickedFile.readAsBytes();
      final base64String = base64Encode(fileBytes);

      final client = ref.read(authProvider.notifier).apiClient;
      final response = await client.patch(
        '/api/v1/users/me/',
        {'avatar': base64String},
      );

      if (response.statusCode == 200) {
        // Save locally and update Riverpod state
        await ref.read(authProvider.notifier).updateUserData({
          'avatar': base64String,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Text('Foto de perfil actualizada en el servidor.', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al subir foto de perfil al servidor.')),
          );
        }
      }
    } catch (e) {
      print('Error picking/uploading avatar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al acceder a la cámara o galería.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _deleteAvatar() async {
    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      final client = ref.read(authProvider.notifier).apiClient;
      final response = await client.patch(
        '/api/v1/users/me/',
        {'avatar': null},
      );

      if (response.statusCode == 200) {
        // Update local Riverpod state
        await ref.read(authProvider.notifier).updateUserData({
          'avatar': null,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Text('Foto de perfil eliminada.', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al eliminar foto de perfil.')),
          );
        }
      }
    } catch (e) {
      print('Error deleting avatar: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  void _changeProfilePicture() {
    final authState = ref.read(authProvider);
    final user = authState.user;
    final hasAvatar = user != null && user['avatar'] != null && user['avatar'].toString().isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0B25),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Foto de Perfil',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecciona una opción para actualizar tu foto de perfil oficial.',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF817BFF)),
                  title: const Text('Tomar Foto', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadAvatar(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF817BFF)),
                  title: const Text('Elegir de la Galería', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadAvatar(ImageSource.gallery);
                  },
                ),
                if (hasAvatar)
                  ListTile(
                    leading: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444)),
                    title: const Text('Eliminar Foto Actual', style: TextStyle(color: Color(0xFFEF4444))),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteAvatar();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E0B25),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Seleccionar Idioma',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Text('🇪🇸', style: TextStyle(fontSize: 20)),
                title: const Text('Español', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF817BFF)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Idioma configurado: Español')),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Text('🇺🇸', style: TextStyle(fontSize: 20)),
                title: const Text('English (Inglés)', style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Configuración en Inglés no disponible en esta demo.')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0B25),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Ajustes de la Aplicación',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Personaliza tu experiencia en Q POINT.',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Notificaciones de Asistencia', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('Alertas de tardanzas y justificaciones', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                      value: _notificationsEnabled,
                      activeColor: const Color(0xFF817BFF),
                      onChanged: (val) {
                        setState(() {
                          _notificationsEnabled = val;
                        });
                        setModalState(() {});
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tema Oscuro (Q POINT)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('Interfaz de alta fidelidad optimizada', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                      value: _darkModeEnabled,
                      activeColor: const Color(0xFF817BFF),
                      onChanged: (val) {
                        setState(() {
                          _darkModeEnabled = val;
                        });
                        setModalState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('El estilo Q POINT está optimizado para Modo Oscuro.')),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF817BFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Guardar Ajustes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAboutBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0B25),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Acerca de Q POINT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Q POINT - Sistema Inteligente de Asistencia QR',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'Versión de la App: v1.2.0 (Producción)\nDesarrollado para control académico de asistencias en tiempo real.',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Soporte Técnico:',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const Text(
                  'reportes-asistencias@universidad.edu.pe',
                  style: TextStyle(color: Color(0xFF817BFF), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF817BFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cerrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E0B25),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text('¿Estás seguro que deseas cerrar tu sesión en Q POINT?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      ref.read(authProvider.notifier).logout();
    }
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color textColor = Colors.white,
    Color iconColor = const Color(0xFF817BFF),
  }) {
    final isLogout = textColor == const Color(0xFFEF4444);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0B25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Icon(icon, color: isLogout ? const Color(0xFFEF4444) : iconColor, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 15.5,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          color: isLogout ? const Color(0xFFEF4444) : Colors.white30,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildActiveNavTab({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF817BFF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF817BFF).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1.0),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: const Color(0xFFC7C5FF),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildFloatingNavBar() {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF817BFF).withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavTab(
              icon: Icons.home_rounded,
              onPressed: () => context.go('/'),
            ),
            _buildNavTab(
              icon: Icons.qr_code_scanner_rounded,
              onPressed: () => context.push('/student/scan'),
            ),
            _buildNavTab(
              icon: Icons.bar_chart_rounded,
              onPressed: () => context.push('/student/history'),
            ),
            _buildActiveNavTab(
              icon: Icons.person_rounded,
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = user?['role'] ?? 'student';
    final isStudent = role == 'student';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0E0B25),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF817BFF).withOpacity(0.2), width: 1.0),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF817BFF), size: 16),
                onPressed: () => context.go('/'),
              ),
            ),
          ),
        ),
        title: const Text(
          'Perfil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0B25),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF817BFF).withOpacity(0.2), width: 1.0),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.menu_rounded, color: Color(0xFF817BFF), size: 20),
                  onPressed: _showSettingsBottomSheet,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isStudent ? _buildFloatingNavBar() : null,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20.0,
          right: 20.0,
          top: 16.0,
          bottom: isStudent ? 120.0 : 40.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User profile section
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _changeProfilePicture,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E0B25),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF817BFF).withOpacity(0.2), width: 2),
                            image: (user != null && user['avatar'] != null && user['avatar'].toString().isNotEmpty)
                                ? DecorationImage(
                                    image: MemoryImage(base64Decode(user['avatar'])),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: (user == null || user['avatar'] == null || user['avatar'].toString().isEmpty)
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.2),
                                )
                              : null,
                        ),
                        if (_isUploadingAvatar)
                          Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF817BFF)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${user?['first_name'] ?? 'Usuario'} ${user?['last_name'] ?? ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?['email'] ?? 'correo@institucional.edu.pe',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // KPI Cards Section
            _isLoadingStats
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF817BFF)),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      // KPI Card 1
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E0B25),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.04)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF817BFF).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  isStudent ? '📈' : '📚',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                isStudent ? '$_avgAttendance%' : '$_totalTeacherCourses',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isStudent ? 'Asistencia' : 'Asignaturas',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // KPI Card 2
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E0B25),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.04)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF817BFF).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  isStudent ? '📚' : '⏱️',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '$_totalCoursesOrSessions',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isStudent ? 'Asignaturas' : 'Sesiones',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 24),
            const SizedBox(height: 8),

            // Settings Menu List
            _buildMenuTile(
              icon: Icons.edit_rounded,
              title: 'Editar Perfil',
              onTap: _changeProfilePicture,
            ),
            _buildMenuTile(
              icon: Icons.translate_rounded,
              title: 'Idioma',
              onTap: _showLanguageDialog,
            ),
            _buildMenuTile(
              icon: Icons.settings_rounded,
              title: 'Ajustes',
              onTap: _showSettingsBottomSheet,
            ),
            _buildMenuTile(
              icon: Icons.info_outline_rounded,
              title: 'Acerca de',
              onTap: _showAboutBottomSheet,
            ),
            _buildMenuTile(
              icon: Icons.logout_rounded,
              title: 'Cerrar Sesión',
              textColor: const Color(0xFFEF4444),
              iconColor: const Color(0xFFEF4444),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}
