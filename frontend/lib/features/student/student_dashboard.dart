import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth_provider.dart';

class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({super.key});

  @override
  ConsumerState<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<StudentDashboard> {
  bool _isLoading = false;
  Map<String, dynamic>? _studentData;
  String? _errorMessage;
  String _selectedFilter = 'Todos'; // Default filter state

  List<dynamic> _todaySessions = [];
  bool _isLoadingSessions = false;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    await Future.wait([
      _fetchStudentReport(),
      _fetchTodaySessions(),
    ]);
  }

  Future<void> _fetchStudentReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(authProvider.notifier).apiClient;
      final response = await client.get('/api/v1/reports/by-student/');
      if (response.statusCode == 200) {
        setState(() {
          _studentData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error al cargar reporte de asistencia';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión. Intente de nuevo.';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTodaySessions() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSessions = true;
    });
    try {
      final client = ref.read(authProvider.notifier).apiClient;
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final response = await client.get('/api/v1/sessions/?start_date=$todayStr&end_date=$todayStr');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _todaySessions = data;
          });
        }
      }
    } catch (e) {
      print('Error fetching today sessions: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSessions = false;
        });
      }
    }
  }

  String _formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        final ampm = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$displayHour:$minute $ampm';
      }
    } catch (e) {
      // fallback
    }
    return timeStr;
  }

  Widget _buildTodaySessionCard(Map<String, dynamic> session) {
    final status = session['status'] ?? 'scheduled';
    final courseName = session['section_detail']?['course_detail']?['name'] ?? 'Curso';
    final sectionCode = session['section_detail']?['code'] ?? '-';
    final classroomName = session['classroom_detail']?['name'] ?? 'Aula';
    final startTimeStr = _formatTime(session['start_time'] ?? '');
    final endTimeStr = _formatTime(session['end_time'] ?? '');
    final teacherName = session['section_detail']?['teacher_name'] ?? 'Docente';

    // Status colors and labels
    Color statusColor;
    String statusLabel;
    bool isActive = false;

    if (status == 'active') {
      statusColor = const Color(0xFF10B981); // Emerald green
      statusLabel = 'Activa (QR Abierto)';
      isActive = true;
    } else if (status == 'closed') {
      statusColor = const Color(0xFF64748B); // Slate gray
      statusLabel = 'Cerrada';
    } else {
      statusColor = const Color(0xFF3B82F6); // Blue
      statusLabel = 'Programada';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0B25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? statusColor.withOpacity(0.5) : const Color(0xFF817BFF).withOpacity(0.1),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: statusColor.withOpacity(0.15),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Time and Room
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Color(0xFF817BFF), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$startTimeStr - $endTimeStr',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.room_rounded, color: Color(0xFF817BFF), size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        classroomName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFC7C5FF), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            courseName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Docente: $teacherName | Sec: $sectionCode',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => context.push('/student/scan'),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.white),
                  label: const Text('Escanear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _getTrafficLightColor(String? light) {
    switch (light) {
      case 'green':
        return const Color(0xFF10B981); // Emerald
      case 'yellow':
        return const Color(0xFFF59E0B); // Amber
      case 'red':
        return const Color(0xFFEF4444); // Red
      default:
        return Colors.grey;
    }
  }

  String _getTrafficLightLabel(String? light) {
    switch (light) {
      case 'green':
        return 'Estable';
      case 'yellow':
        return 'En Riesgo';
      case 'red':
        return 'Riesgo Crítico';
      default:
        return 'Desconocido';
    }
  }

  double _calculateAverageAttendance() {
    if (_studentData == null || _studentData!['courses'] == null || _studentData!['courses'].isEmpty) {
      return 0.0;
    }
    final courses = _studentData!['courses'] as List;
    double total = 0.0;
    for (var course in courses) {
      total += (course['attendance_percentage'] as num).toDouble();
    }
    return double.parse((total / courses.length).toStringAsFixed(1));
  }

  void _showCourseDetail(Map<String, dynamic> course) {
    final status = course['traffic_light'];
    final color = _getTrafficLightColor(status);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0B25),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        course['course_name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        _getTrafficLightLabel(status),
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Sección: ${course['section_code']} | Docente: ${course['teacher']}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCircle('Asistencias', course['attended'], const Color(0xFF10B981)),
                    _buildStatCircle('Tardanzas', course['tardies'], const Color(0xFFF59E0B)),
                    _buildStatCircle('Faltas', course['absences'], const Color(0xFFEF4444)),
                    _buildStatCircle('Justificados', course['justified'], const Color(0xFF38BDF8)),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF817BFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCircle(String label, dynamic value, Color color) {
    final displayVal = value?.toString() ?? '0';
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            displayVal,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildFilterTag(String label, String value) {
    final isActive = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF817BFF) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF817BFF) : Colors.white.withOpacity(0.04),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSquareTopButton({required IconData icon, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF0E0B25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF817BFF).withOpacity(0.2), width: 1.0),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: const Color(0xFF817BFF), size: 20),
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
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
              label: 'Inicio',
              isActive: true,
              onPressed: () {},
            ),
            _buildNavTab(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Escanear QR',
              isActive: false,
              onPressed: () => context.push('/student/scan'),
            ),
            _buildNavTab(
              icon: Icons.calendar_month_rounded,
              label: 'Historial',
              isActive: false,
              onPressed: () => context.push('/student/history'),
            ),
            _buildNavTab(
              icon: Icons.settings_rounded,
              label: 'Ajustes',
              isActive: false,
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTab({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    final activeColor = const Color(0xFF817BFF);
    final inactiveColor = const Color(0xFF94A3B8);

    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : inactiveColor,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 10,
              ),
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
    final avgAttendance = _calculateAverageAttendance();

    final courses = _studentData?['courses'] as List? ?? [];
    final filteredCourses = courses.where((c) {
      if (_selectedFilter == 'Todos') return true;
      return c['traffic_light'] == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Pure black background
      bottomNavigationBar: _buildFloatingNavBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF817BFF)),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 60, color: Color(0xFFEF4444)),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchStudentReport,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF817BFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchStudentReport,
                  color: const Color(0xFF817BFF),
                  backgroundColor: const Color(0xFF0E0B25),
                  child: SafeArea(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Custom Top Bar (Profile Section)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0E0B25),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF817BFF).withOpacity(0.2), width: 1.0),
                                      image: (user != null && user['avatar'] != null && user['avatar'].toString().isNotEmpty)
                                          ? DecorationImage(
                                              image: MemoryImage(base64Decode(user['avatar'])),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: (user == null || user['avatar'] == null || user['avatar'].toString().isEmpty)
                                        ? Center(
                                            child: Text(
                                              (user?['first_name']?[0] ?? 'A').toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${user?['first_name'] ?? 'Estudiante'} ${user?['last_name'] ?? ''}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Matrícula: ${user?['student_code'] ?? '-'}',
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  _buildSquareTopButton(
                                    icon: Icons.refresh_rounded,
                                    onPressed: _fetchDashboardData,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSquareTopButton(
                                    icon: Icons.settings_rounded,
                                    onPressed: () => context.push('/settings'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // KPI Stat Cards Row (Dark Themed with Periwinkle accents)
                          Row(
                            children: [
                              // Attendance card (Wide)
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0E0B25),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF817BFF).withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: Color(0xFF817BFF), size: 18),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'Promedio Gral.',
                                            style: TextStyle(
                                              color: Color(0xFFC7C5FF),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '$avgAttendance%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: avgAttendance / 100,
                                          minHeight: 6,
                                          backgroundColor: Colors.white.withOpacity(0.08),
                                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF817BFF)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Rank/Courses card (Narrow)
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0E0B25),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF817BFF).withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.emoji_events_rounded, color: Color(0xFF817BFF), size: 18),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'Cursos',
                                            style: TextStyle(
                                              color: Color(0xFFC7C5FF),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${courses.length}',
                                        style: const TextStyle(
                                          color: Color(0xFF817BFF),
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Inscritos',
                                        style: TextStyle(
                                          color: Color(0x8AFFFFFF),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Today's Classes Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Clases de Hoy',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (_todaySessions.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF817BFF).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${_todaySessions.length} sesio${_todaySessions.length == 1 ? 'n' : 'nes'}',
                                    style: const TextStyle(
                                      color: Color(0xFF817BFF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _isLoadingSessions
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16.0),
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF817BFF)),
                                    ),
                                  ),
                                )
                              : _todaySessions.isEmpty
                                  ? Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0E0B25),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFF817BFF).withOpacity(0.1)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.calendar_today_rounded, color: Color(0xFF817BFF), size: 20),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'No tienes clases programadas para hoy.',
                                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Column(
                                      children: _todaySessions.map((session) {
                                        return _buildTodaySessionCard(session);
                                      }).toList(),
                                    ),
                          const SizedBox(height: 28),

                          // Category Filters Section
                          const Text(
                            'Categoría por Estado',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterTag('Todos', 'Todos'),
                                _buildFilterTag('Estables', 'green'),
                                _buildFilterTag('En Riesgo', 'yellow'),
                                _buildFilterTag('Críticos', 'red'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Course Grid Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Mis Asignaturas',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedFilter = 'Todos';
                                  });
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF817BFF),
                                ),
                                child: const Text('Ver Todo', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (filteredCourses.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.04)),
                              ),
                              child: const Text(
                                'No se encontraron asignaturas en esta categoría.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: filteredCourses.length,
                              itemBuilder: (context, index) {
                                final course = filteredCourses[index];
                                final trafficColor = _getTrafficLightColor(course['traffic_light']);
                                final cardBgColor = const Color(0xFF0E0B25);
                                final textColor = Colors.white;
                                final subtitleColor = Colors.white70;
                                final symbolBg = trafficColor.withOpacity(0.12);
                                final symbolColor = trafficColor;

                                return GestureDetector(
                                  onTap: () => _showCourseDetail(course),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: trafficColor.withOpacity(0.3), width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: trafficColor.withOpacity(0.05),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: symbolBg,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              alignment: Alignment.center,
                                              child: Icon(Icons.school_rounded, color: symbolColor, size: 20),
                                            ),
                                            Text(
                                              '${course['attendance_percentage']}%',
                                              style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              course['course_name'],
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Sección: ${course['section_code']}',
                                              style: TextStyle(
                                                color: subtitleColor,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
