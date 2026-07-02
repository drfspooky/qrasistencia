import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/auth_provider.dart';

class TeacherDashboard extends ConsumerStatefulWidget {
  const TeacherDashboard({super.key});

  @override
  ConsumerState<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends ConsumerState<TeacherDashboard> {
  bool _isLoading = false;
  List<dynamic> _sessions = [];
  String? _errorMessage;
  String _selectedTab = 'today';
  bool _showGuide = true;
  String _dateSpan = 'week';
  DateTime? _selectedCustomDate;

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  Map<String, String> _getDateRangeParams() {
    final now = DateTime.now();
    String startStr = '';
    String endStr = '';

    if (_dateSpan == 'today') {
      final start = DateTime(now.year, now.month, now.day);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      startStr = DateFormat('yyyy-MM-dd').format(start);
      endStr = DateFormat('yyyy-MM-dd').format(end);
    } else if (_dateSpan == 'week') {
      final start = now.subtract(const Duration(days: 7));
      final end = now.add(const Duration(days: 7));
      startStr = DateFormat('yyyy-MM-dd').format(start);
      endStr = DateFormat('yyyy-MM-dd').format(end);
    } else if (_dateSpan == 'month') {
      final start = now.subtract(const Duration(days: 30));
      final end = now.add(const Duration(days: 30));
      startStr = DateFormat('yyyy-MM-dd').format(start);
      endStr = DateFormat('yyyy-MM-dd').format(end);
    } else if (_dateSpan == 'custom_date' && _selectedCustomDate != null) {
      final start = _selectedCustomDate!;
      final end = _selectedCustomDate!;
      startStr = DateFormat('yyyy-MM-dd').format(start);
      endStr = DateFormat('yyyy-MM-dd').format(end);
    }
    
    final Map<String, String> params = {};
    if (startStr.isNotEmpty) params['start_date'] = startStr;
    if (endStr.isNotEmpty) params['end_date'] = endStr;
    return params;
  }

  Future<void> _fetchSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(authProvider.notifier).apiClient;
      
      final dateParams = _getDateRangeParams();
      String queryPath = '/api/v1/sessions/';
      if (dateParams.isNotEmpty) {
        final queryStr = Uri(queryParameters: dateParams).query;
        queryPath = '$queryPath?$queryStr';
      }

      final response = await client.get(queryPath);
      if (response.statusCode == 200) {
        setState(() {
          _sessions = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error al cargar las sesiones de clase';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión';
        _isLoading = false;
      });
    }
  }

  Future<void> _openSession(int id) async {
    final toleranceController = TextEditingController(text: '15');
    
    final int? selectedTolerance = await showDialog<int>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF0E0B25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF817BFF).withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.timer_outlined, color: Color(0xFF817BFF)),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Iniciar Sesión',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Define el tiempo límite de tolerancia (en minutos) para marcar la asistencia de los alumnos.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tolerancia de Asistencia (minutos)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: toleranceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    hintText: 'Ej. 15',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF817BFF)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF817BFF), Color(0xFF5B21B6)],
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          final input = toleranceController.text.trim();
                          final val = int.tryParse(input) ?? 15;
                          Navigator.pop(context, val);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Comenzar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedTolerance == null) return; // User cancelled

    setState(() => _isLoading = true);
    try {
      final client = ref.read(authProvider.notifier).apiClient;
      final response = await client.post('/api/v1/sessions/$id/open/', {
        'tolerance_minutes': selectedTolerance,
      });
      
      if (response.statusCode == 200) {
        _fetchSessions();
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['detail'] ?? 'Error al abrir la sesión'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _closeSession(int id) async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(authProvider.notifier).apiClient;
      final response = await client.post('/api/v1/sessions/$id/close/', {});
      
      if (response.statusCode == 200) {
        _fetchSessions();
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['detail'] ?? 'Error al cerrar la sesión'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Widget _buildGuideStep(String stepNumber, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFF817BFF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    bool isLive = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0C24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              if (isLive)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isTodayTab = label == 'Hoy';
    
    // Choose colors based on tab type
    Color activeColorStart = isTodayTab ? const Color(0xFF817BFF) : const Color(0xFF475569);
    Color activeColorEnd = isTodayTab ? const Color(0xFF5B21B6) : const Color(0xFF334155);
    
    IconData tabIcon = isTodayTab ? Icons.today_rounded : Icons.history_rounded;
    Color iconColor = isActive 
        ? Colors.white 
        : (isTodayTab ? const Color(0xFF817BFF) : const Color(0xFF64748B));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [activeColorStart, activeColorEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : const Color(0xFF0E0B25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive 
                ? Colors.transparent 
                : Colors.white.withOpacity(0.04),
            width: 1.2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColorStart.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tabIcon, size: 15, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive 
                    ? Colors.white.withOpacity(0.18) 
                    : (isTodayTab ? const Color(0xFF817BFF).withOpacity(0.08) : const Color(0xFF64748B).withOpacity(0.08)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isActive 
                      ? Colors.white 
                      : (isTodayTab ? const Color(0xFF817BFF) : const Color(0xFF94A3B8)),
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
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

    // Filter sessions
    final scheduledSessions = _sessions.where((s) => s['status'] == 'scheduled').toList();
    final activeSessions = _sessions.where((s) => s['status'] == 'active').toList();
    final closedSessions = _sessions.where((s) => s['status'] == 'closed').toList();

    final todaySessionsList = [...activeSessions, ...scheduledSessions];
    final historySessionsList = closedSessions;

    final displaySessions = _selectedTab == 'today' ? todaySessionsList : historySessionsList;

    final scheduledCount = scheduledSessions.length;
    final activeCount = activeSessions.length;
    final closedCount = closedSessions.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Portal Docente', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchSessions,
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchSessions,
        color: const Color(0xFF817BFF),
        backgroundColor: const Color(0xFF0E0B25),
        child: _isLoading && _sessions.isEmpty
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF817BFF))))
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
                          const SizedBox(height: 16),
                          Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchSessions,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF817BFF)),
                            child: const Text('Reintentar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      // Header & Profile Banner
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF817BFF), Color(0xFF5B21B6)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF817BFF).withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                ),
                                child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '¡Hola, ${user?['first_name'] ?? 'Docente'}!',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF817BFF).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF817BFF).withOpacity(0.3), width: 1),
                                          ),
                                          child: const Text(
                                            'DOCENTE',
                                            style: TextStyle(
                                              color: Color(0xFF817BFF),
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            user?['email'] ?? '',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ),

                      // Didactic Guide Banner
                      if (_showGuide)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: const Color(0xFF817BFF).withOpacity(0.2)),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF817BFF).withOpacity(0.12),
                                      const Color(0xFF5B21B6).withOpacity(0.04),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.school_rounded, color: Color(0xFF817BFF), size: 22),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Guía Rápida de Asistencia',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                                          onPressed: () => setState(() => _showGuide = false),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    _buildGuideStep('1', 'Comienza la clase', 'Presiona "Abrir Sesión" en la clase asignada hoy y define la tolerancia.'),
                                    const SizedBox(height: 10),
                                    _buildGuideStep('2', 'Proyecta el QR', 'Entra a "Proyectar QR" para que los alumnos escaneen el código dinámico.'),
                                    const SizedBox(height: 10),
                                    _buildGuideStep('3', 'Monitorea y Cierra', 'Verás a los alumnos registrarse en tiempo real. Al finalizar la clase, cierra la sesión.'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // KPI Counters Summary
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'Programadas',
                                  value: scheduledCount.toString(),
                                  icon: Icons.calendar_today_rounded,
                                  iconColor: const Color(0xFF817BFF),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'En Curso',
                                  value: activeCount.toString(),
                                  icon: Icons.play_circle_outline_rounded,
                                  iconColor: const Color(0xFF10B981),
                                  isLive: activeCount > 0,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'Historial',
                                  value: closedCount.toString(),
                                  icon: Icons.check_circle_outline_rounded,
                                  iconColor: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Tabs for Clases de Hoy vs Historial + Date filter dropdown
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  _buildTabButton(
                                    label: 'Hoy',
                                    count: todaySessionsList.length,
                                    isActive: _selectedTab == 'today',
                                    onTap: () => setState(() => _selectedTab = 'today'),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildTabButton(
                                    label: 'Historial',
                                    count: historySessionsList.length,
                                    isActive: _selectedTab == 'history',
                                    onTap: () => setState(() => _selectedTab = 'history'),
                                  ),
                                ],
                              ),
                              
                              // Date span selector
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F0C24),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _dateSpan,
                                    dropdownColor: const Color(0xFF0E0B25),
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF817BFF)),
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    onChanged: (String? newValue) async {
                                      if (newValue == 'custom_date') {
                                        final DateTime? picked = await showDatePicker(
                                          context: context,
                                          initialDate: _selectedCustomDate ?? DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2030),
                                          locale: const Locale('es', 'ES'),
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme: const ColorScheme.dark(
                                                  primary: Color(0xFF817BFF),
                                                  onPrimary: Colors.white,
                                                  surface: Color(0xFF0E0B25),
                                                  onSurface: Colors.white,
                                                ),
                                                dialogBackgroundColor: const Color(0xFF0E0B25),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            _dateSpan = 'custom_date';
                                            _selectedCustomDate = picked;
                                          });
                                          _fetchSessions();
                                        }
                                      } else if (newValue != null) {
                                        setState(() {
                                          _dateSpan = newValue;
                                        });
                                        _fetchSessions();
                                      }
                                    },
                                    items: [
                                      const DropdownMenuItem(value: 'today', child: Text('Hoy')),
                                      const DropdownMenuItem(value: 'week', child: Text('± 7 días')),
                                      const DropdownMenuItem(value: 'month', child: Text('± 30 días')),
                                      const DropdownMenuItem(value: 'all', child: Text('Todas')),
                                      DropdownMenuItem(
                                        value: 'custom_date',
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF817BFF)),
                                            const SizedBox(width: 6),
                                            Text(_selectedCustomDate == null
                                                ? 'Calendario...'
                                                : DateFormat('dd/MM/yy').format(_selectedCustomDate!)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Filtered Sessions List
                      if (displaySessions.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _selectedTab == 'today' 
                                        ? Icons.calendar_today_rounded 
                                        : Icons.folder_off_rounded, 
                                    color: const Color(0xFF475569), 
                                    size: 56,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _selectedTab == 'today' 
                                        ? 'No hay clases pendientes hoy' 
                                        : 'Historial vacío',
                                    style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _selectedTab == 'today' 
                                        ? 'Tus sesiones programadas para hoy se mostrarán en esta pestaña.' 
                                        : 'Las clases que cierres se archivarán aquí automáticamente.',
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final session = displaySessions[index];
                                final section = session['section_detail'];
                                final course = section['course_detail'];
                                final classroom = session['classroom_detail'];
                                final dateStr = session['date'];
                                final timeStr = "${session['start_time'].toString().substring(0,5)} - ${session['end_time'].toString().substring(0,5)}";
                                
                                final status = session['status'];
                                final statusDisplay = session['status_display'];
                                
                                Color statusColor;
                                Color statusBg;
                                String statusInstruction;
                                BoxDecoration? borderDecor;

                                if (status == 'scheduled') {
                                  statusColor = const Color(0xFF817BFF);
                                  statusBg = const Color(0xFF817BFF).withOpacity(0.1);
                                  statusInstruction = 'Esta clase aún no inicia. Presiona "Abrir Sesión" para habilitar la tolerancia.';
                                  borderDecor = BoxDecoration(
                                    border: Border.all(color: const Color(0xFF817BFF).withOpacity(0.2), width: 1.2),
                                    borderRadius: BorderRadius.circular(24),
                                  );
                                } else if (status == 'active') {
                                  statusColor = const Color(0xFF10B981);
                                  statusBg = const Color(0xFF10B981).withOpacity(0.1);
                                  statusInstruction = 'Clase en curso. Presiona "Proyectar QR" para mostrar el escáner a los alumnos.';
                                  borderDecor = BoxDecoration(
                                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4), width: 1.5),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withOpacity(0.04),
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  );
                                } else {
                                  statusColor = const Color(0xFF64748B);
                                  statusBg = const Color(0xFF64748B).withOpacity(0.1);
                                  statusInstruction = 'Esta clase ya finalizó. El registro de asistencia está cerrado.';
                                  borderDecor = BoxDecoration(
                                    border: Border.all(color: Colors.white.withOpacity(0.04), width: 1.0),
                                    borderRadius: BorderRadius.circular(24),
                                  );
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: borderDecor,
                                  child: Card(
                                    margin: EdgeInsets.zero,
                                    child: Padding(
                                      padding: const EdgeInsets.all(18.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (status == 'active') ...[
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 6.0, right: 10.0),
                                                  child: GlowingActiveIndicator(),
                                                ),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  course['name'],
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.5),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: statusBg,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                                                ),
                                                child: Text(
                                                  statusDisplay,
                                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              const Icon(Icons.class_outlined, size: 14, color: Color(0xFF64748B)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Sección: ${section['code']}  |  Aula: ${classroom['name']}',
                                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.schedule_outlined, size: 14, color: Color(0xFF64748B)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Fecha: $dateStr  |  Hora: $timeStr',
                                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                                ),
                                              ),
                                            ],
                                          ),
                                          
                                          // Step Instructions Indicator (Didactic Flow)
                                          const SizedBox(height: 14),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.02),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  status == 'active' 
                                                      ? Icons.check_circle_outline_rounded 
                                                      : status == 'scheduled' 
                                                          ? Icons.info_outline_rounded 
                                                          : Icons.lock_outline_rounded,
                                                  size: 14,
                                                  color: statusColor.withOpacity(0.7),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    statusInstruction,
                                                    style: TextStyle(
                                                      color: statusColor.withOpacity(0.8),
                                                      fontSize: 11.5,
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              if (status == 'scheduled')
                                                Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(12),
                                                    gradient: const LinearGradient(
                                                      colors: [Color(0xFF817BFF), Color(0xFF5B21B6)],
                                                    ),
                                                  ),
                                                  child: ElevatedButton.icon(
                                                    onPressed: () => _openSession(session['id']),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.transparent,
                                                      shadowColor: Colors.transparent,
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                    ),
                                                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                                    label: const Text('Abrir Sesión', style: TextStyle(fontWeight: FontWeight.bold)),
                                                  ),
                                                )
                                              else if (status == 'active') ...[
                                                OutlinedButton.icon(
                                                  onPressed: () => _closeSession(session['id']),
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: Color(0xFFEF4444)),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                  ),
                                                  icon: const Icon(Icons.stop_rounded, color: Color(0xFFEF4444), size: 18),
                                                  label: const Text('Cerrar', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                                                ),
                                                const SizedBox(width: 10),
                                                Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(12),
                                                    gradient: const LinearGradient(
                                                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFF10B981).withOpacity(0.25),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 4),
                                                      )
                                                    ]
                                                  ),
                                                  child: ElevatedButton.icon(
                                                    onPressed: () => context.push('/teacher/session/${session['id']}'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.transparent,
                                                      shadowColor: Colors.transparent,
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                    ),
                                                    icon: const Icon(Icons.qr_code_rounded, size: 18),
                                                    label: const Text('Proyectar QR', style: TextStyle(fontWeight: FontWeight.bold)),
                                                  ),
                                                ),
                                              ] else
                                                TextButton.icon(
                                                  onPressed: () => context.push('/teacher/session/${session['id']}'),
                                                  style: TextButton.styleFrom(
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                  icon: const Icon(Icons.analytics_outlined, color: Color(0xFF817BFF), size: 18),
                                                  label: const Text('Ver Asistencias', style: TextStyle(color: Color(0xFF817BFF), fontWeight: FontWeight.bold)),
                                                ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: displaySessions.length,
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class GlowingActiveIndicator extends StatefulWidget {
  const GlowingActiveIndicator({super.key});

  @override
  State<GlowingActiveIndicator> createState() => _GlowingActiveIndicatorState();
}

class _GlowingActiveIndicatorState extends State<GlowingActiveIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF10B981).withOpacity(_pulseAnimation.value),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.6),
                blurRadius: 6 * _pulseAnimation.value,
                spreadRadius: 2 * _pulseAnimation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
