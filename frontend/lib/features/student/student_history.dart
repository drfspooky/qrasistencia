import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth_provider.dart';

class StudentHistoryPage extends ConsumerStatefulWidget {
  const StudentHistoryPage({super.key});

  @override
  ConsumerState<StudentHistoryPage> createState() => _StudentHistoryPageState();
}

class _StudentHistoryPageState extends ConsumerState<StudentHistoryPage> {
  bool _isLoading = false;
  List<dynamic> _records = [];
  String? _errorMessage;
  String _selectedFilter = 'Todos';
  String _dateSpan = '30';

  Map<String, String> _getDateRangeParams() {
    final now = DateTime.now();
    String startStr = '';
    String endStr = '';

    if (_dateSpan == '7') {
      final start = now.subtract(const Duration(days: 7));
      startStr = DateFormat('yyyy-MM-dd').format(start);
      endStr = DateFormat('yyyy-MM-dd').format(now);
    } else if (_dateSpan == '30') {
      final start = now.subtract(const Duration(days: 30));
      startStr = DateFormat('yyyy-MM-dd').format(start);
      endStr = DateFormat('yyyy-MM-dd').format(now);
    } else if (_dateSpan == '90') {
      final start = now.subtract(const Duration(days: 90));
      startStr = DateFormat('yyyy-MM-dd').format(start);
      endStr = DateFormat('yyyy-MM-dd').format(now);
    }
    
    final Map<String, String> params = {};
    if (startStr.isNotEmpty) params['start_date'] = startStr;
    if (endStr.isNotEmpty) params['end_date'] = endStr;
    return params;
  }

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(authProvider.notifier).apiClient;
      
      final dateParams = _getDateRangeParams();
      String queryPath = '/api/v1/records/';
      if (dateParams.isNotEmpty) {
        final queryStr = Uri(queryParameters: dateParams).query;
        queryPath = '$queryPath?$queryStr';
      }

      final response = await client.get(queryPath);
      if (response.statusCode == 200) {
        setState(() {
          _records = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error al cargar el historial';
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

  void _openJustifyDialog(int recordId) {
    final reasonController = TextEditingController();
    final documentUrlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF0E0B25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          child: SingleChildScrollView(
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
                        child: const Icon(Icons.note_add_rounded, color: Color(0xFF817BFF)),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Enviar Justificación',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Por favor, ingresa el motivo de tu inasistencia y opcionalmente adjunta un enlace con el sustento correspondiente.',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  
                  // Label & TextField for Motivo
                  const Text(
                    'Motivo o Sustento',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      hintText: 'Ej. Cita médica, problemas de salud, etc.',
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
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Label & TextField for Link
                  const Text(
                    'Enlace de Sustento (Opcional)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: documentUrlController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      prefixIcon: Icon(Icons.link, color: Colors.white.withOpacity(0.4), size: 18),
                      hintText: 'Ej. Enlace a Google Drive, Dropbox, etc.',
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
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
                          onPressed: () async {
                            final reason = reasonController.text.trim();
                            final docUrl = documentUrlController.text.trim();
                            if (reason.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Debe ingresar un motivo.')),
                              );
                              return;
                            }
                            Navigator.pop(context);
                            await _submitJustification(recordId, reason, docUrl);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Enviar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitJustification(int recordId, String reason, String docUrl) async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(authProvider.notifier).apiClient;
      final response = await client.post('/api/v1/attendance/$recordId/justify/', {
        'reason': reason,
        'document_url': docUrl,
      });

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text('Justificación enviada correctamente.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
        _fetchHistory();
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF4444),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(data['detail'] ?? 'Error al enviar justificación', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFEF4444),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Error de conexión.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'presente':
        return const Color(0xFF10B981);
      case 'tardanza':
        return const Color(0xFFF59E0B);
      case 'falta':
        return const Color(0xFFEF4444);
      case 'justificado':
        return const Color(0xFF817BFF);
      case 'retiro_anticipado':
        return const Color(0xFFF97316);
      default:
        return Colors.grey;
    }
  }

  Widget _buildSummaryCard(double attendanceRate) {
    Color progressColor = const Color(0xFF10B981);
    String statusTitle = "¡Récord Excelente! 🎉";
    String statusMessage = "Estás asistiendo regularmente a todas tus clases. ¡Sigue así!";

    if (attendanceRate < 70.0) {
      progressColor = const Color(0xFFEF4444);
      statusTitle = "Riesgo de Inhabilitación ⚠️";
      statusMessage = "Has superado el 30% de inasistencias permitidas en varios cursos.";
    } else if (attendanceRate < 85.0) {
      progressColor = const Color(0xFFF59E0B);
      statusTitle = "Alerta de Asistencia 📚";
      statusMessage = "Ten cuidado con las faltas acumuladas, asiste a las próximas sesiones.";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0E0B25), const Color(0xFF1B123E).withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: progressColor.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular progress on the left
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: attendanceRate / 100.0,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
                Center(
                  child: Text(
                    '${attendanceRate.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          // Description details on the right
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Asistencia General',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  statusTitle,
                  style: TextStyle(color: progressColor, fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  statusMessage,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11.5, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0B25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  label,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['Todos', 'Presentes', 'Tardanzas', 'Faltas', 'Justificados'];
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          
          Color activeColor = const Color(0xFF817BFF);
          if (filter == 'Presentes') activeColor = const Color(0xFF10B981);
          if (filter == 'Tardanzas') activeColor = const Color(0xFFF59E0B);
          if (filter == 'Faltas') activeColor = const Color(0xFFEF4444);
          if (filter == 'Justificados') activeColor = const Color(0xFF817BFF);

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withOpacity(0.12) : const Color(0xFF0E0B25),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? activeColor : Colors.white.withOpacity(0.04),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineItemRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    bool showLine = true,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indicator column
        Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            if (showLine)
              Container(
                width: 2,
                height: 24,
                color: Colors.white10,
              ),
          ],
        ),
        const SizedBox(width: 12),
        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineCard(dynamic record) {
    final session = record['session_detail'] ?? {};
    final section = session['section_detail'] ?? {};
    final course = section['course_detail'] ?? {};
    final courseName = course['name'] ?? 'Curso sin nombre';
    final dateStr = session['date'] ?? '';
    final timeStr = session['start_time'] ?? '';
    final recordedAtStr = record['recorded_at'];

    String displayTime = "-";
    if (recordedAtStr != null) {
      try {
        displayTime = DateFormat('HH:mm').format(DateTime.parse(recordedAtStr).toLocal());
      } catch (_) {}
    }

    final status = record['status'] ?? '';
    final statusDisplay = record['status_display'] ?? '';
    final color = _getStatusColor(status);
    final hasCheckOut = record['check_out'] != null;

    String checkOutDisplay = "-";
    if (hasCheckOut) {
      try {
        checkOutDisplay = DateFormat('HH:mm').format(DateTime.parse(record['check_out']).toLocal());
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0B25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04), width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Accent Status Indicator
              Container(width: 5, color: color),
              // Card Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              courseName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color.withOpacity(0.2), width: 1),
                            ),
                            child: Text(
                              statusDisplay,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      
                      // Intern Timeline Path of Check-in/out
                      // 1. Programmed session details
                      _buildTimelineItemRow(
                        icon: Icons.calendar_today_rounded,
                        color: Colors.white24,
                        title: 'Clase Programada',
                        subtitle: '$dateStr a las $timeStr',
                        showLine: true,
                      ),
                      
                      // 2. Entrance (check-in) log details
                      _buildTimelineItemRow(
                        icon: status == 'presente' 
                            ? Icons.check_circle_rounded 
                            : status == 'tardanza' 
                                ? Icons.watch_later_rounded 
                                : Icons.cancel_rounded,
                        color: color,
                        title: status == 'presente' 
                            ? 'Entrada Puntual' 
                            : status == 'tardanza' 
                                ? 'Ingreso con Tardanza' 
                                : 'Inasistencia Registrada',
                        subtitle: recordedAtStr != null 
                            ? 'Hora de registro: $displayTime (${record['recorded_by_display'] ?? ''})' 
                            : 'No se registró marcación de entrada.',
                        showLine: hasCheckOut,
                      ),
                      
                      // 3. Exit (check-out) log details (conditional)
                      if (hasCheckOut)
                        _buildTimelineItemRow(
                          icon: Icons.logout_rounded,
                          color: const Color(0xFF64748B),
                          title: 'Salida Registrada',
                          subtitle: 'Hora de salida: $checkOutDisplay',
                          showLine: false,
                        ),
                      
                      // Geo Valid check warning badge
                      if (record['geo_valid'] == false) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.15), width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 12),
                              SizedBox(width: 6),
                              Text(
                                'Fuera de rango geográfico',
                                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10.5, fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                        ),
                      ],

                      // Justification actions or status banners
                      if (record['justification_status'] != null) ...[
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white10, height: 1),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.note_rounded, size: 13, color: Colors.white.withOpacity(0.4)),
                            const SizedBox(width: 8),
                            Text(
                              'Justificación: ',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12.5),
                            ),
                            Text(
                              record['justification_status'] == 'pending'
                                  ? 'Pendiente ⏳'
                                  : record['justification_status'] == 'approved'
                                      ? 'Aprobada ✅'
                                      : 'Rechazada ❌',
                              style: TextStyle(
                                color: record['justification_status'] == 'approved'
                                    ? const Color(0xFF10B981)
                                    : record['justification_status'] == 'pending'
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFFEF4444),
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ] else if (status == 'falta' || status == 'tardanza') ...[
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white10, height: 1),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF817BFF), Color(0xFF5B21B6)],
                              ),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _openJustifyDialog(record['id']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.note_add_rounded, size: 14),
                              label: const Text(
                                'Justificar',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate metric parameters dynamically
    final int totalClases = _records.length;
    final int presentes = _records.where((r) => r['status'] == 'presente').length;
    final int tardanzas = _records.where((r) => r['status'] == 'tardanza').length;
    final int faltas = _records.where((r) => r['status'] == 'falta' && r['justification_status'] != 'approved' && r['justification_status'] != 'pending').length;
    final int justificados = _records.where((r) => r['status'] == 'justificado' || r['justification_status'] == 'approved' || r['justification_status'] == 'pending').length;

    double attendanceRate = totalClases == 0 
        ? 100.0 
        : ((presentes + justificados + tardanzas) / totalClases) * 100.0;

    // Filter records list based on selected tab filter
    final filteredRecords = _records.where((record) {
      final status = record['status'] ?? '';
      final justStatus = record['justification_status'] ?? '';
      
      if (_selectedFilter == 'Todos') return true;
      if (_selectedFilter == 'Presentes') return status == 'presente';
      if (_selectedFilter == 'Tardanzas') return status == 'tardanza';
      if (_selectedFilter == 'Faltas') return status == 'falta' && justStatus != 'approved' && justStatus != 'pending';
      if (_selectedFilter == 'Justificados') return status == 'justificado' || justStatus == 'approved' || justStatus == 'pending';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Mi Historial',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.go('/'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
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
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _dateSpan = newValue;
                      });
                      _fetchHistory();
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: '7', child: Text('7 días')),
                    DropdownMenuItem(value: '30', child: Text('30 días')),
                    DropdownMenuItem(value: '90', child: Text('90 días')),
                    DropdownMenuItem(value: 'all', child: Text('Todo')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF817BFF)),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Attendance general rate progress card
                      _buildSummaryCard(attendanceRate),
                      const SizedBox(height: 12),
                      
                      // Quick mini stats row
                      Row(
                        children: [
                          _buildMiniStat('Clases', totalClases, const Color(0xFF817BFF), Icons.school_rounded),
                          const SizedBox(width: 8),
                          _buildMiniStat('Tardanzas', tardanzas, const Color(0xFFF59E0B), Icons.watch_later_rounded),
                          const SizedBox(width: 8),
                          _buildMiniStat('Faltas', faltas, const Color(0xFFEF4444), Icons.cancel_rounded),
                        ],
                      ),
                      
                      // Horizontally scrollable status filter tags
                      _buildFilterChips(),
                      
                      // List of cards or empty message
                      filteredRecords.isEmpty
                          ? const Expanded(
                              child: Center(
                                child: Text(
                                  'No hay registros para este filtro.',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                                ),
                              ),
                            )
                          : Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.only(bottom: 24),
                                itemCount: filteredRecords.length,
                                itemBuilder: (context, index) {
                                  return _buildTimelineCard(filteredRecords[index]);
                                },
                              ),
                            ),
                    ],
                  ),
                ),
    );
  }
}
