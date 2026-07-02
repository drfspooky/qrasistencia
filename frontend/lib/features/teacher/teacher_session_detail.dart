import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth_provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class TeacherSessionDetailPage extends ConsumerStatefulWidget {
  final int sessionId;

  const TeacherSessionDetailPage({super.key, required this.sessionId});

  @override
  ConsumerState<TeacherSessionDetailPage> createState() => _TeacherSessionDetailPageState();
}

class _TeacherSessionDetailPageState extends ConsumerState<TeacherSessionDetailPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _sessionDetail;
  Map<String, dynamic>? _attendanceSummary;
  List<dynamic> _attendances = [];
  List<dynamic> _justifications = [];
  
  String? _qrCodeToken;
  Timer? _qrRefreshTimer;
  Timer? _countdownTimer;
  Timer? _listRefreshTimer;
  int _refreshIntervalSeconds = 15;
  int _secondsRemaining = 15;
  bool _autoRefreshQR = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    _listRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchAttendanceListOnly());
  }

  @override
  void dispose() {
    _qrRefreshTimer?.cancel();
    _countdownTimer?.cancel();
    _listRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    await _fetchSessionData();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchSessionData() async {
    try {
      final client = ref.read(authProvider.notifier).apiClient;
      
      final sessionRes = await client.get('/api/v1/sessions/${widget.sessionId}/');
      if (sessionRes.statusCode == 200) {
        _sessionDetail = jsonDecode(sessionRes.body);
        
        if (_sessionDetail!['status'] == 'active' && _qrCodeToken == null) {
          await _generateQRCode();
          _startQRTimer();
        }
      }

      final summaryRes = await client.get('/api/v1/sessions/${widget.sessionId}/attendance_summary/');
      if (summaryRes.statusCode == 200) {
        _attendanceSummary = jsonDecode(summaryRes.body);
      }

      final recordsRes = await client.get('/api/v1/records/?session_id=${widget.sessionId}');
      if (recordsRes.statusCode == 200) {
        _attendances = jsonDecode(recordsRes.body);
      }

      final justRes = await client.get('/api/v1/justifications/?session_id=${widget.sessionId}');
      if (justRes.statusCode == 200) {
        _justifications = jsonDecode(justRes.body);
      }
    } catch (_) {}
  }

  Future<void> _fetchAttendanceListOnly() async {
    if (_isLoading) return;
    try {
      final client = ref.read(authProvider.notifier).apiClient;
      final summaryRes = await client.get('/api/v1/sessions/${widget.sessionId}/attendance_summary/');
      final recordsRes = await client.get('/api/v1/records/?session_id=${widget.sessionId}');
      final justRes = await client.get('/api/v1/justifications/?session_id=${widget.sessionId}');
      
      if (summaryRes.statusCode == 200 && recordsRes.statusCode == 200 && justRes.statusCode == 200 && mounted) {
        setState(() {
          _attendanceSummary = jsonDecode(summaryRes.body);
          _attendances = jsonDecode(recordsRes.body);
          _justifications = jsonDecode(justRes.body);
        });
      }
    } catch (_) {}
  }

  Future<void> _resolveJustification(int justificationId, String statusVal, String overrideStatus) async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(authProvider.notifier).apiClient;
      final res = await client.post('/api/v1/attendance/correct/', {
        'justification_id': justificationId,
        'status': statusVal,
        'override_status': overrideStatus,
        'reason': 'Resolución de justificación aprobada/rechazada por docente desde la app.'
      });
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Justificación resuelta correctamente.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        await _fetchSessionData();
      } else {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['detail'] ?? 'Error al resolver justificación'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _generateQRCode() async {
    try {
      final client = ref.read(authProvider.notifier).apiClient;
      debugPrint('Generating QR token for session ${widget.sessionId}...');
      final response = await client.post('/api/v1/sessions/${widget.sessionId}/generate-qr/', {
        'duration_seconds': _refreshIntervalSeconds + 5
      });
      debugPrint('Generate QR response status: ${response.statusCode}');
      debugPrint('Generate QR response body: ${response.body}');
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          _qrCodeToken = data['code'];
          _secondsRemaining = _refreshIntervalSeconds;
        });
      } else {
        debugPrint('Error generating QR: status code is ${response.statusCode}');
      }
    } catch (e, stack) {
      debugPrint('Exception in _generateQRCode: $e');
      debugPrint(stack.toString());
    }
  }

  void _startQRTimer() {
    _qrRefreshTimer?.cancel();
    _countdownTimer?.cancel();
    debugPrint('Starting QR timer. status: ${_sessionDetail?['status']}, autoRefresh: $_autoRefreshQR');
    if (!_autoRefreshQR || _sessionDetail?['status'] != 'active') return;

    setState(() => _secondsRemaining = _refreshIntervalSeconds);
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 1) {
            _secondsRemaining--;
          } else {
            _secondsRemaining = _refreshIntervalSeconds;
          }
        });
      }
    });

    _qrRefreshTimer = Timer.periodic(Duration(seconds: _refreshIntervalSeconds), (_) async {
      if (mounted) {
        await _generateQRCode();
      }
    });
  }

  Future<void> _closeSession() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(authProvider.notifier).apiClient;
      await client.post('/api/v1/sessions/${widget.sessionId}/close/', {});
      _qrRefreshTimer?.cancel();
      _countdownTimer?.cancel();
      _qrCodeToken = null;
      await _fetchSessionData();
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _exportPdf() async {
    try {
      final client = ref.read(authProvider.notifier).apiClient;
      final token = await client.getAccessToken();
      final urlString = '${client.baseUrl}/api/v1/sessions/${widget.sessionId}/export-pdf/?token=$token';
      
      final url = Uri.parse(urlString);
      await url_launcher.launchUrl(url, mode: url_launcher.LaunchMode.externalApplication);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace de descarga')),
      );
    }
  }

  void _openManualEditDialog(Map<String, dynamic> record) {
    final statusOptions = ['presente', 'tardanza', 'falta', 'retiro_anticipado', 'justificado'];
    String selectedStatus = record['status'];
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0B25),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                ),
                padding: const EdgeInsets.all(24),
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
                          child: const Icon(Icons.edit_note_rounded, color: Color(0xFF817BFF)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Modificar Asistencia',
                                style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                record['student_name'],
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Styled pill tags for status selection
                    const Text(
                      'Seleccionar Estado',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: statusOptions.map((opt) {
                        final isSelected = selectedStatus == opt;
                        Color stateColor = _getStatusColor(opt);
                        
                        IconData stateIcon;
                        switch (opt) {
                          case 'presente':
                            stateIcon = Icons.check_circle_rounded;
                            break;
                          case 'tardanza':
                            stateIcon = Icons.watch_later_rounded;
                            break;
                          case 'falta':
                            stateIcon = Icons.cancel_rounded;
                            break;
                          case 'justificado':
                            stateIcon = Icons.note_rounded;
                            break;
                          case 'retiro_anticipado':
                            stateIcon = Icons.logout_rounded;
                            break;
                          default:
                            stateIcon = Icons.help_outline_rounded;
                        }

                        return InkWell(
                          onTap: () {
                            setDialogState(() => selectedStatus = opt);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? stateColor.withOpacity(0.12) : Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? stateColor : Colors.white.withOpacity(0.08),
                                width: 1.5,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: stateColor.withOpacity(0.1),
                                  blurRadius: 8,
                                  spreadRadius: -2,
                                )
                              ] : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(stateIcon, size: 13, color: isSelected ? stateColor : Colors.white60),
                                const SizedBox(width: 4),
                                Text(
                                  opt.replaceAll('_', ' ').toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white60,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    
                    // Audit log change reason field
                    TextField(
                      controller: reasonController,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Motivo del cambio (Obligatorio)',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12.5),
                        hintText: 'Ej. Justificación médica presentada',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.03),
                        contentPadding: const EdgeInsets.all(12),
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
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Historical audit logs list
                    const Text(
                      'Historial de Auditoría',
                      style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: FutureBuilder<http.Response>(
                        future: ref.read(authProvider.notifier).apiClient.get('/api/v1/records/${record['id']}/audit_logs/'),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          }
                          if (snapshot.hasError || snapshot.data?.statusCode != 200) {
                            return const Center(
                              child: Text('Sin historial previo.', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            );
                          }
                          final logs = jsonDecode(snapshot.data!.body) as List;
                          if (logs.isEmpty) {
                            return const Center(
                              child: Text('Sin modificaciones registradas.', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            );
                          }
                          return ListView.builder(
                            itemCount: logs.length,
                            itemBuilder: (context, idx) {
                              final log = logs[idx];
                              final time = DateFormat('dd/MM HH:mm').format(DateTime.parse(log['timestamp']).toLocal());
                              final oldStatus = (log['old_status'] ?? 'falta').toString().toUpperCase();
                              final newStatus = (log['new_status'] ?? '').toString().toUpperCase();
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF817BFF),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                log['changed_by_name'] ?? 'Usuario',
                                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                time,
                                                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9.5),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$oldStatus ➡️ $newStatus',
                                            style: TextStyle(color: _getStatusColor(log['new_status'] ?? ''), fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Motivo: ${log['reason'] ?? "-"}',
                                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, height: 1.3),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
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
                          child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF817BFF), Color(0xFF5B21B6)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF817BFF).withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          ),
                          child: ElevatedButton(
                            onPressed: () async {
                              final reason = reasonController.text.trim();
                              if (reason.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Debe especificar un motivo para el cambio.'),
                                    backgroundColor: Color(0xFFEF4444),
                                  ),
                                );
                                return;
                              }
                              Navigator.pop(context);
                              await _saveManualAttendance(record['id'], selectedStatus, reason);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'Guardar',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
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
      },
    );
  }

  Future<void> _saveManualAttendance(int recordId, String newStatus, String reason) async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(authProvider.notifier).apiClient;
      final res = await client.post('/api/v1/attendance/manual/', {
        'attendance_id': recordId,
        'status': newStatus,
        'reason': reason,
      });

      if (res.statusCode == 200) {
        await _fetchSessionData();
      } else {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['detail'] ?? 'Error al guardar'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (_) {}
    setState(() => _isLoading = false);
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
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _sessionDetail == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF060913),
        body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF817BFF)))),
      );
    }

    final section = _sessionDetail?['section_detail'];
    final course = section?['course_detail'];
    final classroom = _sessionDetail?['classroom_detail'];
    final status = _sessionDetail?['status'] ?? 'closed';

    return Scaffold(
      backgroundColor: const Color(0xFF060913),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(course?['name'] ?? 'Detalle de Sesión', style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF817BFF)),
            tooltip: 'Exportar PDF',
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Metadata Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Aula: ${classroom?['name'] ?? '-'}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: status == 'active' ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFEF4444).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: status == 'active' ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFEF4444).withOpacity(0.3)),
                          ),
                          child: Text(
                            _sessionDetail?['status_display']?.toUpperCase() ?? '-',
                            style: TextStyle(
                              color: status == 'active' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sección: ${section?['code'] ?? '-'}  |  Tolerancia: ${_sessionDetail?['tolerance_minutes'] ?? '-'} min',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fecha: ${_sessionDetail?['date'] ?? '-'}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    if (status == 'active') ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _closeSession,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.stop_rounded, color: Color(0xFFEF4444), size: 18),
                          label: const Text('Cerrar Sesión Escáner', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // QR Projection
            if (status == 'active') ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CÓDIGO QR ACTIVO',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Actualización dinámica de seguridad',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                              ),
                            ],
                          ),
                          // Countdown timer circle
                          SizedBox(
                            width: 38,
                            height: 38,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: _secondsRemaining / _refreshIntervalSeconds,
                                  strokeWidth: 3,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF817BFF)),
                                  backgroundColor: Colors.white10,
                                ),
                                Text(
                                  '$_secondsRemaining',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // QR Code Container with neon borders and custom coloring
                      if (_qrCodeToken != null)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF060913),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF817BFF).withOpacity(0.3), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF817BFF).withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: 1,
                              )
                            ]
                          ),
                          padding: const EdgeInsets.all(20),
                          child: QrImageView(
                            data: _qrCodeToken!,
                            version: QrVersions.auto,
                            size: 200.0,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF817BFF),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        const SizedBox(
                          height: 240,
                          child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF817BFF)))),
                        ),
                        
                      const SizedBox(height: 24),
                      
                      // Refresh config dropdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.speed_rounded, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          const Text('Intervalo:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                          const SizedBox(width: 10),
                          DropdownButton<int>(
                            value: _refreshIntervalSeconds,
                            dropdownColor: const Color(0xFF0D1527),
                            style: const TextStyle(color: Color(0xFF817BFF), fontWeight: FontWeight.bold, fontSize: 13),
                            underline: Container(height: 1, color: const Color(0xFF817BFF)),
                            items: [10, 15, 30, 60].map((sec) {
                              return DropdownMenuItem(
                                value: sec,
                                child: Text('cada $sec seg'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _refreshIntervalSeconds = val;
                                });
                                _startQRTimer();
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_qrCodeToken != null)
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _qrCodeToken!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Token copiado al portapapeles'),
                                duration: Duration(seconds: 2),
                                backgroundColor: Color(0xFF817BFF),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Token: ${_qrCodeToken!.length > 15 ? "${_qrCodeToken!.substring(0, 15)}..." : _qrCodeToken}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF817BFF)),
                              ],
                            ),
                          ),
                        )
                      else
                        const Text(
                          'Token: -',
                          style: TextStyle(fontFamily: 'monospace', color: Color(0xFF475569), fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Real-time Summary
            if (_attendanceSummary != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Text('Resumen de Asistencia', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _SummaryCard(label: 'Presentes', count: _attendanceSummary!['presente'], color: const Color(0xFF10B981)),
                  _SummaryCard(label: 'Tardanzas', count: _attendanceSummary!['tardanza'], color: const Color(0xFFF59E0B)),
                  _SummaryCard(label: 'Faltas', count: _attendanceSummary!['falta'], color: const Color(0xFFEF4444)),
                  _SummaryCard(label: 'Justificados', count: _attendanceSummary!['justificado'], color: const Color(0xFF817BFF)),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Detailed Student List
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Lista de Alumnos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Row(
                    children: [
                      Icon(Icons.sync, size: 12, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text('Tiempo Real', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _attendances.length,
              itemBuilder: (context, index) {
                final record = _attendances[index];
                final status = record['status'];
                final statusDisplay = record['status_display'];
                final color = _getStatusColor(status);
                
                String logTime = "-";
                if (record['recorded_at'] != null) {
                  logTime = DateFormat('HH:mm').format(DateTime.parse(record['recorded_at']).toLocal());
                }

                // Render student initials
                final nameParts = record['student_name'].toString().split(' ');
                final initials = nameParts.length > 1 
                    ? "${nameParts[0].substring(0,1)}${nameParts[1].substring(0,1)}"
                    : nameParts[0].substring(0,2);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withOpacity(0.3), width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials.toUpperCase(),
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    title: Text(record['student_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      'Código: ${record['student_code']}  |  Marcado: $logTime\nRegistro: ${record['recorded_by_display']}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.4),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withOpacity(0.3), width: 1),
                          ),
                          child: Text(
                            statusDisplay,
                            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF817BFF)),
                          onPressed: () => _openManualEditDialog(record),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            
            // Justifications
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Text('Justificaciones Recibidas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 12),
            if (_justifications.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No hay justificaciones registradas.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _justifications.length,
                itemBuilder: (context, index) {
                  final just = _justifications[index];
                  final studentName = just['attendance_detail']['student_name'];
                  final code = just['attendance_detail']['student_code'];
                  final reason = just['reason'];
                  final docUrl = just['document_url'] ?? '';
                  final justStatus = just['status'];

                  Color stateCol;
                  if (justStatus == 'pending') {
                    stateCol = const Color(0xFFF59E0B);
                  } else if (justStatus == 'approved') {
                    stateCol = const Color(0xFF10B981);
                  } else {
                    stateCol = const Color(0xFFEF4444);
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(studentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: stateCol.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: stateCol.withOpacity(0.3)),
                                ),
                                child: Text(
                                  just['status_display'],
                                  style: TextStyle(
                                    color: stateCol,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Código: $code', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          const SizedBox(height: 12),
                          const Text('Motivo de Inasistencia:', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(reason, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                          if (docUrl.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.attach_file_rounded, size: 14, color: Color(0xFF817BFF)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    docUrl,
                                    style: const TextStyle(color: Color(0xFF817BFF), fontSize: 12, decoration: TextDecoration.underline),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (justStatus == 'pending') ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _resolveJustification(just['id'], 'rejected', 'falta'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFEF4444)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  child: const Text('Rechazar', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                                    ),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () => _resolveJustification(just['id'], 'approved', 'justificado'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    ),
                                    child: const Text('Aprobar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            )
                          ]
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: const Color(0xFF0D1527),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
