import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth_provider.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  bool _isLoading = false;
  List<dynamic> _coursesReport = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAdminReport();
  }

  Future<void> _fetchAdminReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(authProvider.notifier).apiClient;
      final response = await client.get('/api/v1/reports/by-course/');
      if (response.statusCode == 200) {
        setState(() {
          _coursesReport = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error al cargar reporte consolidado';
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

  Future<void> _downloadReport(String format, int sectionId) async {
    final client = ref.read(authProvider.notifier).apiClient;
    final path = format == 'pdf' ? '/api/v1/reports/export/pdf/' : '/api/v1/reports/export/excel/';
    final urlStr = "${client.baseUrl}$path?section_id=$sectionId";
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Descargando reporte $format...'),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF817BFF),
      ),
    );

    try {
      final uri = Uri.parse(urlStr);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir el enlace de descarga: $urlStr'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double globalAvgAttendance = 0.0;
    int totalAlertsGreen = 0;
    int totalAlertsYellow = 0;
    int totalAlertsRed = 0;

    if (_coursesReport.isNotEmpty) {
      double sumAvg = 0.0;
      for (final item in _coursesReport) {
        sumAvg += item['average_attendance'];
        totalAlertsGreen += (item['alerts']['green'] as num).toInt();
        totalAlertsYellow += (item['alerts']['yellow'] as num).toInt();
        totalAlertsRed += (item['alerts']['red'] as num).toInt();
      }
      globalAvgAttendance = sumAvg / _coursesReport.length;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF060913),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Panel de Administración', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchAdminReport,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAdminReport,
        color: const Color(0xFF817BFF),
        backgroundColor: const Color(0xFF0E0B25),
        child: _isLoading && _coursesReport.isEmpty
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
                            onPressed: _fetchAdminReport,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF817BFF)),
                            child: const Text('Reintentar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  )
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      // Admin Profile Header
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF817BFF), Color(0xFF5B21B6)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF817BFF).withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                ),
                                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 30),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Portal Administrativo',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'ADMINISTRADOR',
                                          style: TextStyle(
                                            color: Color(0xFF817BFF),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Asistencias e Indicadores',
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 12,
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

                      // KPI Indicators
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4.0, bottom: 12),
                                child: Text(
                                  'Indicadores de Asistencia Global',
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Row(
                                children: [
                                  _StatCard(
                                    label: 'Asistencia Promedio',
                                    value: '${globalAvgAttendance.toStringAsFixed(1)}%',
                                    color: const Color(0xFF817BFF),
                                  ),
                                  _StatCard(
                                    label: 'Alumnos en Verde',
                                    value: '$totalAlertsGreen',
                                    color: const Color(0xFF10B981),
                                  ),
                                  _StatCard(
                                    label: 'Alumnos en Rojo',
                                    value: '$totalAlertsRed',
                                    color: const Color(0xFFEF4444),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Section reports title
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 32, bottom: 16),
                          child: const Text(
                            'Reportes Consolidados por Curso',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      if (_coursesReport.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text('No hay datos disponibles.', style: TextStyle(color: Color(0xFF64748B))),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = _coursesReport[index];
                                final avg = item['average_attendance'];
                                final sectionId = item['section_id'];

                                Color avgColor;
                                if (avg >= 85) {
                                  avgColor = const Color(0xFF10B981);
                                } else if (avg >= 70) {
                                  avgColor = const Color(0xFFF59E0B);
                                } else {
                                  avgColor = const Color(0xFFEF4444);
                                }

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item['course_name'],
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: avgColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: avgColor.withOpacity(0.3), width: 1),
                                              ),
                                              child: Text(
                                                '$avg%',
                                                style: TextStyle(color: avgColor, fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Sección: ${item['section_code']}  |  Docente: ${item['teacher']}',
                                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                        ),
                                        Text(
                                          'Periodo: ${item['period']}',
                                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                        ),
                                        const SizedBox(height: 16),
                                        const Divider(color: Colors.white10),
                                        const SizedBox(height: 16),
                                        
                                        // Traffic Light (Semaforo) alert summary chips
                                        Row(
                                          children: [
                                            _AlertIndicator(label: 'Estables', count: item['alerts']['green'], color: const Color(0xFF10B981)),
                                            _AlertIndicator(label: 'Tardanzas', count: item['alerts']['yellow'], color: const Color(0xFFF59E0B)),
                                            _AlertIndicator(label: 'Críticos', count: item['alerts']['red'], color: const Color(0xFFEF4444)),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        
                                        // Excel & PDF export buttons
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () => _downloadReport('excel', sectionId),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: Color(0xFF10B981)),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              ),
                                              icon: const Icon(Icons.table_view_rounded, color: Color(0xFF10B981), size: 16),
                                              label: const Text('Excel', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 10),
                                            ElevatedButton.icon(
                                              onPressed: () => _downloadReport('pdf', sectionId),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFEF4444),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              ),
                                              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                              label: const Text('Exportar PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              childCount: _coursesReport.length,
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1527),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10, width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 12,
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertIndicator extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _AlertIndicator({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
