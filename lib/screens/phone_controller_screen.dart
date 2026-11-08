import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/phone_controller.dart';

class PhoneControllerScreen extends StatefulWidget {
  final String roomCode;

  const PhoneControllerScreen({super.key, required this.roomCode});

  @override
  State<PhoneControllerScreen> createState() => _PhoneControllerScreenState();
}

class _PhoneControllerScreenState extends State<PhoneControllerScreen> {
  late final PhoneController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PhoneController(roomCode: widget.roomCode);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;

    // Se o smartphone estiver em pé (Portrait), rotaciona o layout para Landscape
    final isPortrait = size.width < size.height;

    Widget controllerContent = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _buildLandscapeUI(
        width: isPortrait ? size.height : size.width,
        height: isPortrait ? size.width : size.height,
      ),
    );

    if (isPortrait) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A12),
        body: Center(
          child: RotatedBox(
            quarterTurns: 1, // 90 graus no modo paisagem forçado
            child: SizedBox(
              width: size.height,
              height: size.width,
              child: controllerContent,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: controllerContent,
    );
  }

  Widget _buildLandscapeUI({required double width, required double height}) {
    final isConnected = _controller.isConnected;

    return SafeArea(
      child: Stack(
        children: [
          // Barra de Status Superior
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status da Conexão
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isConnected ? const Color(0xFF00E676) : Colors.orangeAccent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isConnected ? Icons.check_circle : Icons.sync,
                        color: isConnected ? const Color(0xFF00E676) : Colors.orangeAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isConnected
                            ? 'TV CONECTADA (${_controller.roomCode}) ${_controller.latency > 0 ? "• ${_controller.latency}ms" : ""}'
                            : 'CONECTANDO À TV...',
                        style: TextStyle(
                          color: isConnected ? const Color(0xFF00E676) : Colors.orangeAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),

                // Botões de Calibrar Sensores e Inverter
                Row(
                  children: [
                    // Indicador de Graus do Sensor
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        _controller.debugSensorText,
                        style: const TextStyle(
                          color: Color(0xFF00FFCC),
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _controller.calibrateZero(),
                      icon: const Icon(Icons.gps_fixed, size: 14, color: Color(0xFF00FFCC)),
                      label: const Text('CALIBRAR ZERO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1E2E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => _controller.toggleInvert(),
                      icon: Icon(
                        Icons.swap_horizontal_circle,
                        color: _controller.isInverted ? const Color(0xFFFF007F) : Colors.white70,
                        size: 22,
                      ),
                      tooltip: 'Inverter Direção',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Centro: Volante Interativo (Gira com o Giroscópio ou com o Dedo!)
          Center(
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                final delta = details.primaryDelta ?? 0.0;
                final newSteer = (_controller.currentSteering + (delta * 0.015)).clamp(-1.0, 1.0);
                _controller.setManualSteering(newSteer);
              },
              onHorizontalDragEnd: (_) {
                _controller.setManualSteering(0.0);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: _controller.currentSteering * 0.9,
                    child: CustomPaint(
                      size: const Size(190, 190),
                      painter: _SteeringWheelPainter(steering: _controller.currentSteering),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Barra de visualização do esterçamento
                  Container(
                    width: 160,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 80 + (_controller.currentSteering * 70) - 6,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FFCC),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'VIRE O CELULAR OU ARRASTE O VOLANTE',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 1),
                  ),
                ],
              ),
            ),
          ),

          // Lado Esquerdo: FREIO / RÉ e SETA ESQUERDA
          Positioned(
            left: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botão de virar para esquerda rápido
                GestureDetector(
                  onTapDown: (_) => _controller.setManualSteering(-0.8),
                  onTapUp: (_) => _controller.setManualSteering(0.0),
                  onTapCancel: () => _controller.setManualSteering(0.0),
                  child: Container(
                    width: 120,
                    height: 45,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF00FFCC), width: 1.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_left, color: Color(0xFF00FFCC), size: 28),
                        Text('ESQUERDA', style: TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ),

                // Pedal de Freio / Ré
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) {
                    _controller.setBrake(true);
                    _controller.triggerHaptic(25);
                  },
                  onPointerMove: (_) {
                    if (!_controller.isBrake) {
                      _controller.setBrake(true);
                    }
                  },
                  onPointerUp: (_) => _controller.setBrake(false),
                  onPointerCancel: (_) => _controller.setBrake(false),
                  child: Container(
                    width: 120,
                    height: 105,
                    decoration: BoxDecoration(
                      color: _controller.isBrake
                          ? const Color(0xFFFF1744)
                          : const Color(0xFF8B0000).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF1744)
                              .withValues(alpha: _controller.isBrake ? 0.7 : 0.2),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pan_tool, color: Colors.white, size: 34),
                        SizedBox(height: 4),
                        Text(
                          'FREIO / RÉ',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lado Direito: ACELERADOR, NITRO e SETA DIREITA
          Positioned(
            right: 16,
            bottom: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Coluna Auxiliar: Seta Direita e Botão de Nitro
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botão de virar para direita
                    GestureDetector(
                      onTapDown: (_) => _controller.setManualSteering(0.8),
                      onTapUp: (_) => _controller.setManualSteering(0.0),
                      onTapCancel: () => _controller.setManualSteering(0.0),
                      child: Container(
                        width: 80,
                        height: 44,
                        margin: const EdgeInsets.only(bottom: 14, right: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00FFCC), width: 1.5),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('DIR', style: TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold, fontSize: 12)),
                            Icon(Icons.arrow_right, color: Color(0xFF00FFCC), size: 26),
                          ],
                        ),
                      ),
                    ),

                    // Botão de Nitro com espaçamento isolado
                    Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) {
                        _controller.setNitro(true);
                        _controller.triggerHaptic(70);
                      },
                      onPointerMove: (_) {
                        if (!_controller.isNitro) {
                          _controller.setNitro(true);
                        }
                      },
                      onPointerUp: (_) => _controller.setNitro(false),
                      onPointerCancel: (_) => _controller.setNitro(false),
                      child: Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: _controller.isNitro
                              ? const Color(0xFF00E5FF)
                              : const Color(0xFF006064).withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF)
                                  .withValues(alpha: _controller.isNitro ? 0.9 : 0.25),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt, color: Colors.white, size: 30),
                            Text(
                              'NITRO',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Pedal Gigante de Acelerar
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) {
                    _controller.setThrottle(true);
                    _controller.triggerHaptic(25);
                  },
                  onPointerMove: (_) {
                    if (!_controller.isThrottle) {
                      _controller.setThrottle(true);
                    }
                  },
                  onPointerUp: (_) => _controller.setThrottle(false),
                  onPointerCancel: (_) => _controller.setThrottle(false),
                  child: Container(
                    width: 140,
                    height: 160,
                    decoration: BoxDecoration(
                      color: _controller.isThrottle
                          ? const Color(0xFF00E676)
                          : const Color(0xFF1B5E20).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E676)
                              .withValues(alpha: _controller.isThrottle ? 0.9 : 0.3),
                          blurRadius: 25,
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.speed, color: Colors.white, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'ACELERAR',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SteeringWheelPainter extends CustomPainter {
  final double steering;

  _SteeringWheelPainter({required this.steering});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Aro Externo
    final rimPaint = Paint()
      ..color = const Color(0xFF222230)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26;
    canvas.drawCircle(center, radius - 13, rimPaint);

    // Pegas esportivas em Magenta
    final gripPaint = Paint()
      ..color = const Color(0xFFFF007F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 13),
      math.pi * 0.75,
      math.pi * 0.5,
      false,
      gripPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 13),
      -math.pi * 0.25,
      math.pi * 0.5,
      false,
      gripPaint,
    );

    // Raios do Volante
    final spokePaint = Paint()
      ..color = const Color(0xFF444455)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, Offset(center.dx - radius + 22, center.dy), spokePaint);
    canvas.drawLine(center, Offset(center.dx + radius - 22, center.dy), spokePaint);
    canvas.drawLine(center, Offset(center.dx, center.dy + radius - 22), spokePaint);

    // Cubo Central
    final hubPaint = Paint()..color = const Color(0xFF151520);
    canvas.drawCircle(center, 38, hubPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF00FFCC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, 38, borderPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'TURBO',
        style: TextStyle(
          color: Color(0xFF00FFCC),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - (textPainter.width / 2), center.dy - (textPainter.height / 2)),
    );
  }

  @override
  bool shouldRepaint(covariant _SteeringWheelPainter oldDelegate) =>
      oldDelegate.steering != steering;
}
