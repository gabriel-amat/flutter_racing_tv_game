import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models/road_segment.dart';
import 'models/traffic_and_scenery.dart';

class RetroPainter extends CustomPainter {
  final List<RoadSegment> segments;
  final List<SceneryItem> scenery;
  final List<TrafficCar> traffic;
  final double position; // posição da câmera ao longo da pista (Z)
  final double playerX; // posição lateral do jogador (-1.0 a 1.0)
  final double speed; // velocidade atual
  final double maxSpeed;
  final double steering; // ângulo do volante
  final bool isThrottle;
  final bool isBraking;
  final bool isNitroActive;
  final double trackLength;
  final int currentLap;
  final double lapTime;
  final String connectionStatus;
  final int latencyMs;

  RetroPainter({
    required this.segments,
    required this.scenery,
    required this.traffic,
    required this.position,
    required this.playerX,
    required this.speed,
    required this.maxSpeed,
    required this.steering,
    required this.isThrottle,
    required this.isBraking,
    required this.isNitroActive,
    required this.trackLength,
    required this.currentLap,
    required this.lapTime,
    required this.connectionStatus,
    required this.latencyMs,
  });

  static const double cameraHeight = 1000.0;
  static const double cameraDepth = 0.84; // FOV
  static const int drawDistance = 220; // segmentos visíveis à frente
  static const double roadWidth = 2000.0;

  @override
  void paint(Canvas canvas, Size size) {
    final baseSegment = _findSegment(position);
    final basePercent = (position % 200.0) / 200.0;
    final playerY = _interpolate(baseSegment.p1.world.y, baseSegment.p2.world.y, basePercent);

    // 1. Desenha o Céu Synthwave Retrô dos Anos 90 em Parallax
    _drawSkyAndMountains(canvas, size, baseSegment.curve);

    // 2. Projeta e Renderiza a Pista 3D (Horizonte até o Jogador)
    double maxy = size.height;
    double x = 0;
    double dx = -(baseSegment.curve * basePercent);

    // Projeta os segmentos à frente
    for (int n = 0; n < drawDistance; n++) {
      final segment = segments[(baseSegment.index + n) % segments.length];
      final looped = segment.index < baseSegment.index;

      segment.p1.project(
        cameraX: playerX * roadWidth - x,
        cameraY: playerY + cameraHeight,
        cameraZ: position - (looped ? trackLength : 0),
        cameraDepth: cameraDepth,
        screenWidth: size.width,
        screenHeight: size.height,
        roadWidth: roadWidth,
      );

      segment.p2.project(
        cameraX: playerX * roadWidth - x - dx,
        cameraY: playerY + cameraHeight,
        cameraZ: position - (looped ? trackLength : 0),
        cameraDepth: cameraDepth,
        screenWidth: size.width,
        screenHeight: size.height,
        roadWidth: roadWidth,
      );

      x += dx;
      dx += segment.curve;

      segment.clipY = maxy;

      // Desenha o segmento apenas se estiver visível (não ocluído por morros)
      final isVis = segment.p1.screen.scale > 0 &&
          segment.p2.screen.scale > 0 &&
          segment.p1.screen.y >= segment.p2.screen.y &&
          segment.p2.screen.y < maxy;

      segment.isVisible = isVis;

      if (isVis) {
        _drawSegment(canvas, size, segment);
        maxy = segment.p2.screen.y;
      }
    }

    // 3. Renderiza Itens de Cenário e Carros Rivais (de trás para frente)
    for (int n = drawDistance - 1; n > 0; n--) {
      final segment = segments[(baseSegment.index + n) % segments.length];

      // Desenha Cenário deste segmento
      for (var item in scenery) {
        if (item.segmentIndex == segment.index) {
          _drawScenery(canvas, size, segment, item);
        }
      }

      // Desenha Carros Rivais neste segmento
      for (var car in traffic) {
        final carSeg = _findSegment(car.z);
        if (carSeg.index == segment.index) {
          _drawTrafficCar(canvas, size, segment, car);
        }
      }
    }

    // 4. Desenha o Carro do Jogador (Testarossa Vermelho Retrô)
    _drawPlayerCar(canvas, size);

    // 5. HUD Arcade dos Anos 90
    _drawHUD(canvas, size);
  }

  void _drawSkyAndMountains(Canvas canvas, Size size, double curve) {
    // Gradiente do Céu: Roxo profundo -> Magenta -> Laranja dourado
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0F051D),
          Color(0xFF380E46),
          Color(0xFF7E1C5E),
          Color(0xFFE25241),
          Color(0xFFFF9E3D),
        ],
        stops: [0.0, 0.3, 0.55, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.55));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.55), skyPaint);

    // Sol Gigante Retrô Synthwave
    final sunCenter = Offset(size.width * 0.5, size.height * 0.32);
    final sunRadius = size.height * 0.16;

    final sunPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF275), Color(0xFFFF0055)],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius));

    canvas.drawCircle(sunCenter, sunRadius, sunPaint);

    // Linhas horizontais recortando o sol retrô
    final sunLinePaint = Paint()
      ..color = const Color(0xFF380E46)
      ..strokeWidth = 3;
    for (int i = 0; i < 6; i++) {
      final y = sunCenter.dy + (i * 11.0);
      canvas.drawLine(
        Offset(sunCenter.dx - sunRadius, y),
        Offset(sunCenter.dx + sunRadius, y),
        sunLinePaint,
      );
    }

    // Montanhas em Silhueta com Parallax
    final mountainOffset = (position * 0.0003 + playerX * 25.0) % size.width;
    final mountainPath = Path();
    mountainPath.moveTo(0, size.height * 0.55);

    for (double mx = -size.width; mx <= size.width * 2; mx += 80) {
      final peakY = size.height * 0.42 + math.sin(mx * 0.02) * 35;
      mountainPath.lineTo(mx - mountainOffset, peakY);
    }
    mountainPath.lineTo(size.width, size.height * 0.55);
    mountainPath.close();

    final mountainPaint = Paint()
      ..color = const Color(0xFF1E0A2A).withValues(alpha: 0.92);
    canvas.drawPath(mountainPath, mountainPaint);
  }

  void _drawSegment(Canvas canvas, Size size, RoadSegment segment) {
    final p1 = segment.p1.screen;
    final p2 = segment.p2.screen;

    // Grama
    final grassPaint = Paint()..color = segment.colors.grass;
    canvas.drawRect(Rect.fromLTRB(0, p2.y, size.width, p1.y), grassPaint);

    // Zebras Vermelhas e Brancas
    final r1 = p1.w * 0.15;
    final r2 = p2.w * 0.15;
    final rumblePaint = Paint()..color = segment.colors.rumble;
    _drawPolygon(canvas, rumblePaint, [
      Offset(p1.x - p1.w - r1, p1.y),
      Offset(p1.x - p1.w, p1.y),
      Offset(p2.x - p2.w, p2.y),
      Offset(p2.x - p2.w - r2, p2.y),
    ]);
    _drawPolygon(canvas, rumblePaint, [
      Offset(p1.x + p1.w + r1, p1.y),
      Offset(p1.x + p1.w, p1.y),
      Offset(p2.x + p2.w, p2.y),
      Offset(p2.x + p2.w + r2, p2.y),
    ]);

    // Pista (Asfalto)
    final roadPaint = Paint()..color = segment.colors.road;
    _drawPolygon(canvas, roadPaint, [
      Offset(p1.x - p1.w, p1.y),
      Offset(p1.x + p1.w, p1.y),
      Offset(p2.x + p2.w, p2.y),
      Offset(p2.x - p2.w, p2.y),
    ]);

    // Faixa Central
    if (segment.colors.lane != null) {
      final l1 = p1.w * 0.03;
      final l2 = p2.w * 0.03;
      final lanePaint = Paint()..color = segment.colors.lane!;
      _drawPolygon(canvas, lanePaint, [
        Offset(p1.x - l1, p1.y),
        Offset(p1.x + l1, p1.y),
        Offset(p2.x + l2, p2.y),
        Offset(p2.x - l2, p2.y),
      ]);
    }
  }

  void _drawScenery(Canvas canvas, Size size, RoadSegment segment, SceneryItem item) {
    final p = segment.p1.screen;
    if (p.scale <= 0) return;
    if (!segment.isVisible && p.y >= segment.clipY) return;

    final spriteX = p.x + (item.offset * p.w);
    final spriteY = p.y;
    final spriteScale = p.scale * 1400.0;

    if (item.type == SceneryType.palmTree) {
      _drawPalmTree(canvas, Offset(spriteX, spriteY), spriteScale);
    } else if (item.type == SceneryType.billboard || item.type == SceneryType.retroSign) {
      _drawSign(canvas, Offset(spriteX, spriteY), spriteScale, item.text ?? 'TURBO');
    }
  }

  void _drawPalmTree(Canvas canvas, Offset bottomCenter, double scale) {
    if (scale < 6) return;
    final trunkHeight = scale * 1.5;
    final trunkWidth = scale * 0.16;

    // Tronco
    final trunkPaint = Paint()..color = const Color(0xFF6D4C41);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(bottomCenter.dx, bottomCenter.dy - (trunkHeight / 2)),
        width: trunkWidth,
        height: trunkHeight,
      ),
      trunkPaint,
    );

    // Folhagem Neon / Anos 90
    final leavesPaint = Paint()..color = const Color(0xFF00E676);
    final leafRadius = scale * 0.55;
    canvas.drawCircle(Offset(bottomCenter.dx, bottomCenter.dy - trunkHeight), leafRadius, leavesPaint);
    canvas.drawCircle(Offset(bottomCenter.dx - leafRadius * 0.6, bottomCenter.dy - trunkHeight + 10), leafRadius * 0.7, leavesPaint);
    canvas.drawCircle(Offset(bottomCenter.dx + leafRadius * 0.6, bottomCenter.dy - trunkHeight + 10), leafRadius * 0.7, leavesPaint);
  }

  void _drawSign(Canvas canvas, Offset bottomCenter, double scale, String text) {
    if (scale < 10) return;
    final signWidth = scale * 1.4;
    final signHeight = scale * 0.6;

    // Postes do Outdoor
    final polePaint = Paint()..color = Colors.grey.shade700;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(bottomCenter.dx, bottomCenter.dy - (scale * 0.6)),
        width: scale * 0.08,
        height: scale * 1.2,
      ),
      polePaint,
    );

    // Placa
    final signRect = Rect.fromCenter(
      center: Offset(bottomCenter.dx, bottomCenter.dy - (scale * 1.1)),
      width: signWidth,
      height: signHeight,
    );
    final signPaint = Paint()..color = const Color(0xFFFF007F);
    canvas.drawRRect(RRect.fromRectAndRadius(signRect, const Radius.circular(4)), signPaint);

    // Borda Neon
    final borderPaint = Paint()
      ..color = const Color(0xFF00FFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(RRect.fromRectAndRadius(signRect, const Radius.circular(4)), borderPaint);
  }

  void _drawTrafficCar(Canvas canvas, Size size, RoadSegment segment, TrafficCar car) {
    final p = segment.p1.screen;
    if (p.scale <= 0) return;
    if (!segment.isVisible && p.y >= segment.clipY) return;

    final carX = p.x + (car.offset * p.w);
    final carY = p.y;
    final carWidth = car.width * p.scale * (size.width / 2);
    final carHeight = car.height * p.scale * (size.width / 2);

    if (carWidth < 8) return;

    // Sombra no asfalto
    final shadowPaint = Paint()..color = Colors.black45;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(carX, carY), width: carWidth * 1.1, height: carHeight * 0.3),
      shadowPaint,
    );

    // Carroceria Retrô
    final bodyPaint = Paint()..color = car.color;
    final bodyRect = Rect.fromCenter(
      center: Offset(carX, carY - (carHeight * 0.5)),
      width: carWidth,
      height: carHeight * 0.7,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(carWidth * 0.1)), bodyPaint);

    // Vidro traseiro escuro
    final glassPaint = Paint()..color = const Color(0xFF1A1A24);
    final glassRect = Rect.fromCenter(
      center: Offset(carX, carY - (carHeight * 0.7)),
      width: carWidth * 0.75,
      height: carHeight * 0.35,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(glassRect, Radius.circular(carWidth * 0.05)), glassPaint);

    // Lanternas Vermelhas Traseiras
    final lightPaint = Paint()..color = const Color(0xFFFF1744);
    canvas.drawRect(
      Rect.fromLTWH(carX - (carWidth * 0.42), carY - (carHeight * 0.45), carWidth * 0.22, carHeight * 0.18),
      lightPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(carX + (carWidth * 0.2), carY - (carHeight * 0.45), carWidth * 0.22, carHeight * 0.18),
      lightPaint,
    );
  }

  void _drawPlayerCar(Canvas canvas, Size size) {
    final carCenter = Offset(size.width * 0.5, size.height * 0.88);
    final carWidth = size.width * 0.19;
    final carHeight = carWidth * 0.55;

    // Inclinação da carroceria conforme esterçamento do volante
    final tiltAngle = steering * 0.08;

    canvas.save();
    canvas.translate(carCenter.dx, carCenter.dy);
    canvas.rotate(tiltAngle);

    // Sombra
    final shadowPaint = Paint()..color = Colors.black54;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 8), width: carWidth * 1.15, height: carHeight * 0.35),
      shadowPaint,
    );

    // Fogo no escapamento (Nitro)
    if (isNitroActive) {
      final flamePaint = Paint()..color = const Color(0xFF00E5FF);
      canvas.drawCircle(Offset(-carWidth * 0.28, carHeight * 0.35), 18 + (math.Random().nextDouble() * 8), flamePaint);
      canvas.drawCircle(Offset(carWidth * 0.28, carHeight * 0.35), 18 + (math.Random().nextDouble() * 8), flamePaint);
      final innerFlame = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(-carWidth * 0.28, carHeight * 0.35), 9, innerFlame);
      canvas.drawCircle(Offset(carWidth * 0.28, carHeight * 0.35), 9, innerFlame);
    }

    // Carroceria Vermelho Ferrari / Testarossa dos anos 90
    final carPaint = Paint()..color = const Color(0xFFE52521);
    final bodyPath = Path()
      ..moveTo(-carWidth * 0.5, carHeight * 0.2)
      ..lineTo(-carWidth * 0.45, -carHeight * 0.25)
      ..lineTo(-carWidth * 0.32, -carHeight * 0.55)
      ..lineTo(carWidth * 0.32, -carHeight * 0.55)
      ..lineTo(carWidth * 0.45, -carHeight * 0.25)
      ..lineTo(carWidth * 0.5, carHeight * 0.2)
      ..close();
    canvas.drawPath(bodyPath, carPaint);

    // Vidro Traseiro
    final glassPaint = Paint()..color = const Color(0xFF10141E);
    final glassPath = Path()
      ..moveTo(-carWidth * 0.36, -carHeight * 0.25)
      ..lineTo(-carWidth * 0.26, -carHeight * 0.5)
      ..lineTo(carWidth * 0.26, -carHeight * 0.5)
      ..lineTo(carWidth * 0.36, -carHeight * 0.25)
      ..close();
    canvas.drawPath(glassPath, glassPaint);

    // Grade do Motor Traseiro (Ranhuras clássicas Testarossa)
    final grillePaint = Paint()..color = Colors.black87..strokeWidth = 2.5;
    for (int i = 0; i < 4; i++) {
      final y = -carHeight * 0.15 + (i * 7.0);
      canvas.drawLine(Offset(-carWidth * 0.35, y), Offset(carWidth * 0.35, y), grillePaint);
    }

    // Lanternas Traseiras (Acesas / Freio Forte)
    final tailLightPaint = Paint()
      ..color = isBraking ? const Color(0xFFFF0033) : const Color(0xFFD50000);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-carWidth * 0.44, -carHeight * 0.08, carWidth * 0.22, carHeight * 0.2),
        const Radius.circular(3),
      ),
      tailLightPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(carWidth * 0.22, -carHeight * 0.08, carWidth * 0.22, carHeight * 0.2),
        const Radius.circular(3),
      ),
      tailLightPaint,
    );

    // Pneus traseiros largos
    final tirePaint = Paint()..color = const Color(0xFF111111);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-carWidth * 0.52, -carHeight * 0.05, carWidth * 0.1, carHeight * 0.35), const Radius.circular(4)),
      tirePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(carWidth * 0.42, -carHeight * 0.05, carWidth * 0.1, carHeight * 0.35), const Radius.circular(4)),
      tirePaint,
    );

    canvas.restore();
  }

  void _drawHUD(Canvas canvas, Size size) {
    final kmh = ((speed / maxSpeed) * 320).round();
    final rpmRatio = (speed / maxSpeed).clamp(0.0, 1.0);

    // Painel Superior Direito (Velocidade e RPM)
    final hudBg = Paint()..color = const Color(0xFF0F0F18).withValues(alpha: 0.85);
    final hudBorder = Paint()
      ..color = const Color(0xFF00FFCC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final panelRect = Rect.fromLTWH(size.width - 270, 20, 250, 135);
    canvas.drawRRect(RRect.fromRectAndRadius(panelRect, const Radius.circular(10)), hudBg);
    canvas.drawRRect(RRect.fromRectAndRadius(panelRect, const Radius.circular(10)), hudBorder);

    // Texto de Velocidade KM/H
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$kmh',
        style: const TextStyle(
          color: Color(0xFF00FFCC),
          fontSize: 52,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          letterSpacing: 2,
        ),
        children: const [
          TextSpan(
            text: ' KM/H',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          )
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(size.width - 250, 26));

    // Barra de RPM
    final rpmBarBg = Paint()..color = Colors.white12;
    canvas.drawRect(Rect.fromLTWH(size.width - 250, 88, 210, 12), rpmBarBg);

    final rpmWidth = 210 * rpmRatio;
    final rpmColor = rpmRatio > 0.85
        ? const Color(0xFFFF1744)
        : (rpmRatio > 0.6 ? const Color(0xFFFFD600) : const Color(0xFF00E676));
    final rpmPaint = Paint()..color = rpmColor;
    canvas.drawRect(Rect.fromLTWH(size.width - 250, 88, rpmWidth, 12), rpmPaint);

    // Indicadores Retrô dos Pedais no HUD (GAS / FREIO / NITRO)
    final pedalY = 108.0;
    final pedalBg = Paint()..color = Colors.black54;

    // GAS
    final gasRect = Rect.fromLTWH(size.width - 250, pedalY, 65, 20);
    canvas.drawRRect(RRect.fromRectAndRadius(gasRect, const Radius.circular(4)), isThrottle ? (Paint()..color = const Color(0xFF00E676)) : pedalBg);
    final gasBorder = Paint()
      ..color = isThrottle ? const Color(0xFF00E676) : Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(RRect.fromRectAndRadius(gasRect, const Radius.circular(4)), gasBorder);
    final gasText = TextPainter(
      text: TextSpan(text: 'ACELERAR', style: TextStyle(color: isThrottle ? Colors.black : Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout();
    gasText.paint(canvas, Offset(size.width - 250 + (65 - gasText.width) / 2, pedalY + 4));

    // FREIO
    final brkRect = Rect.fromLTWH(size.width - 177, pedalY, 65, 20);
    canvas.drawRRect(RRect.fromRectAndRadius(brkRect, const Radius.circular(4)), isBraking ? (Paint()..color = const Color(0xFFFF1744)) : pedalBg);
    final brkBorder = Paint()
      ..color = isBraking ? const Color(0xFFFF1744) : Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(RRect.fromRectAndRadius(brkRect, const Radius.circular(4)), brkBorder);
    final brkText = TextPainter(
      text: TextSpan(text: 'FREIO', style: TextStyle(color: isBraking ? Colors.white : Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout();
    brkText.paint(canvas, Offset(size.width - 177 + (65 - brkText.width) / 2, pedalY + 4));

    // NITRO
    final nitroRect = Rect.fromLTWH(size.width - 105, pedalY, 65, 20);
    canvas.drawRRect(RRect.fromRectAndRadius(nitroRect, const Radius.circular(4)), isNitroActive ? (Paint()..color = const Color(0xFF00E5FF)) : pedalBg);
    final nitroBorder = Paint()
      ..color = isNitroActive ? const Color(0xFF00E5FF) : Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(RRect.fromRectAndRadius(nitroRect, const Radius.circular(4)), nitroBorder);
    final nitroText = TextPainter(
      text: TextSpan(text: 'NITRO', style: TextStyle(color: isNitroActive ? Colors.black : Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout();
    nitroText.paint(canvas, Offset(size.width - 105 + (65 - nitroText.width) / 2, pedalY + 4));

    // Painel Superior Esquerdo (Tempo de Volta e Status)
    final leftPanel = Rect.fromLTWH(20, 20, 300, 110);
    canvas.drawRRect(RRect.fromRectAndRadius(leftPanel, const Radius.circular(10)), hudBg);
    canvas.drawRRect(RRect.fromRectAndRadius(leftPanel, const Radius.circular(10)), hudBorder);

    final lapText = TextPainter(
      text: TextSpan(
        text: 'LAP: $currentLap\n',
        style: const TextStyle(color: Color(0xFFFF007F), fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        children: [
          TextSpan(
            text: 'TIME: ${lapTime.toStringAsFixed(1)}s\n',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: '$connectionStatus | PING: ${latencyMs}ms',
            style: TextStyle(
              color: connectionStatus.contains('CONECTADO') ? const Color(0xFF00E676) : Colors.orangeAccent,
              fontSize: 13,
            ),
          )
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    lapText.paint(canvas, const Offset(35, 30));
  }

  RoadSegment _findSegment(double z) {
    final index = ((z / 200.0).floor() % segments.length).toInt();
    return segments[index];
  }

  double _interpolate(double a, double b, double percent) => a + (b - a) * percent;

  void _drawPolygon(Canvas canvas, Paint paint, List<Offset> points) {
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant RetroPainter oldDelegate) => true;
}
