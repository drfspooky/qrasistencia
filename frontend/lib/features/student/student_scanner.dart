import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth_provider.dart';

class StudentScannerPage extends ConsumerStatefulWidget {
  const StudentScannerPage({super.key});

  @override
  ConsumerState<StudentScannerPage> createState() => _StudentScannerPageState();
}

class _StudentScannerPageState extends ConsumerState<StudentScannerPage> with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController();
  final _manualTokenController = TextEditingController();
  bool _isProcessing = false;
  String? _statusMessage;
  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualTokenController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<Position?> _getCurrentLocation() async {
    setState(() => _statusMessage = "Obteniendo ubicación GPS...");
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return null;
      } 

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _processScan(String qrCode) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = "Procesando marcación...";
    });

    final position = await _getCurrentLocation();
    
    final payload = {
      'qr_code': qrCode,
      'latitude': position?.latitude,
      'longitude': position?.longitude,
    };

    try {
      final client = ref.read(authProvider.notifier).apiClient;
      final response = await client.post('/api/v1/attendance/scan/', payload);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final statusVal = data['status_display'];
        final timeStr = data['recorded_at'] != null 
            ? DateTime.parse(data['recorded_at']).toLocal().toString().substring(11, 16)
            : '';
            
        if (mounted) {
          _showResultDialog(
            isSuccess: true,
            title: "¡Asistencia Registrada!",
            message: "Estado: $statusVal\nHora: $timeStr u.",
          );
        }
      } else {
        final data = jsonDecode(response.body);
        final err = data['detail'] ?? 'Error desconocido';
        if (mounted) {
          _showResultDialog(
            isSuccess: false,
            title: "Error al registrar",
            message: err,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showResultDialog(
          isSuccess: false,
          title: "Error de conexión",
          message: "No se pudo comunicar con el servidor backend.",
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
      }
    }
  }

  void _showResultDialog({required bool isSuccess, required String title, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1527),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white10, width: 1),
              boxShadow: [
                BoxShadow(
                  color: (isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.15),
                  blurRadius: 40,
                  spreadRadius: 5,
                )
              ]
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.1),
                    border: Border.all(
                      color: (isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                    size: 40,
                    color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 15,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (isSuccess) {
                        context.go('/');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Entendido",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: const Color(0xFF0E0B25).withOpacity(0.6),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => context.go('/'),
                ),
              ),
            ),
          ),
        ),
        title: const Text('Escanear QR', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          // 1. Scanner view
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _processScan(barcode.rawValue!);
                    break;
                  }
                }
              },
            ),
          ),
          
          // 2. Custom overlay painter
          Positioned.fill(
            child: CustomPaint(
              painter: ScannerOverlayPainter(),
            ),
          ),
          
          // 3. Scan guides with laser line
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF817BFF).withOpacity(0.8), width: 2),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF817BFF).withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ]
              ),
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _scanLineAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: 15 + (_scanLineAnimation.value * 230),
                        left: 15,
                        right: 15,
                        child: Container(
                          height: 3.0,
                          decoration: BoxDecoration(
                            color: const Color(0xFF817BFF),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF817BFF).withOpacity(0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // 4. Instructions
          const Positioned(
            top: 140,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Text(
                  'Alinea el código QR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'El registro se realizará automáticamente',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // 5. Manual entry box
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: SafeArea(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E0B25).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10, width: 1),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ingreso Manual',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ingresa el token de sesión si tienes problemas de escaneo.',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualTokenController,
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13), // dark text for visibility
                              decoration: InputDecoration(
                                hintText: 'Ej. UUID de sesión...',
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9), // light grey inside manual entry field
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF817BFF), width: 1),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF817BFF), Color(0xFF7C3AED)],
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                final token = _manualTokenController.text.trim();
                                if (token.isNotEmpty) {
                                  _processScan(token);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Enviar',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.75),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF817BFF))),
                      const SizedBox(height: 20),
                      Text(
                        _statusMessage ?? 'Procesando...',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.65);
    
    const cutoutWidth = 260.0;
    const cutoutHeight = 260.0;
    final left = (size.width - cutoutWidth) / 2;
    final top = (size.height - cutoutHeight) / 2;
    
    final cutoutRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, cutoutWidth, cutoutHeight),
      const Radius.circular(28),
    );
    
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(cutoutRect),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
