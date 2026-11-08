import 'dart:math' as math;
import 'dart:ui';
import 'models/road_segment.dart';
import 'models/traffic_and_scenery.dart';

class TrackBuilder {
  static const double segmentLength = 200.0;
  static const double roadWidth = 2000.0;
  static const int rumbleLength = 3;
  static const int lanes = 3;

  static List<RoadSegment> buildTrack({
    required List<SceneryItem> outScenery,
    required List<TrafficCar> outTraffic,
  }) {
    final List<RoadSegment> segments = [];

    // Paleta de Cores Estilo Anos 90 Retrô (Arcade Synthwave / OutRun)
    final lightColors = RoadColors(
      road: const Color(0xFF42424E),
      grass: const Color(0xFF104A27),
      rumble: const Color(0xFFE52521),
      lane: const Color(0xFFFFFFFF),
    );

    final darkColors = RoadColors(
      road: const Color(0xFF383842),
      grass: const Color(0xFF0D3B1F),
      rumble: const Color(0xFFFFFFFF),
      lane: null,
    );

    void addSegment({
      required double curve,
      required double y,
    }) {
      final index = segments.length;
      final isLight = (index / rumbleLength).floor() % 2 == 0;

      final prevY = segments.isNotEmpty ? segments.last.p2.world.y : 0.0;

      final p1 = RoadPoint(
        world: WorldPoint(x: 0, y: prevY, z: index * segmentLength),
        screen: ScreenPoint(),
      );

      final p2 = RoadPoint(
        world: WorldPoint(x: 0, y: y, z: (index + 1) * segmentLength),
        screen: ScreenPoint(),
      );

      segments.add(RoadSegment(
        index: index,
        p1: p1,
        p2: p2,
        curve: curve,
        colors: isLight ? lightColors : darkColors,
      ));
    }

    void addRoad({
      required int enter,
      required int hold,
      required int leave,
      required double curve,
      required double y,
    }) {
      final startY = segments.isNotEmpty ? segments.last.p2.world.y : 0.0;
      final endY = startY + (y * segmentLength);
      final total = enter + hold + leave;

      for (int n = 0; n < enter; n++) {
        final ratio = n / enter;
        final currentCurve = curve * _easeIn(ratio);
        final currentY = _easeInOut(startY, endY, n / total);
        addSegment(curve: currentCurve, y: currentY);
      }

      for (int n = 0; n < hold; n++) {
        final currentY = _easeInOut(startY, endY, (enter + n) / total);
        addSegment(curve: curve, y: currentY);
      }

      for (int n = 0; n < leave; n++) {
        final ratio = 1.0 - (n / leave);
        final currentCurve = curve * _easeInOut(0, 1, ratio);
        final currentY = _easeInOut(startY, endY, (enter + hold + n) / total);
        addSegment(curve: currentCurve, y: currentY);
      }
    }

    // 1. Reta de Largada (GRID DE SAÍDA)
    addRoad(enter: 20, hold: 40, leave: 20, curve: 0, y: 0);

    // 2. Curva Suave à Direita
    addRoad(enter: 30, hold: 50, leave: 30, curve: 2.2, y: 0);

    // 3. Subida de Colina Íngreme (Efeito "Cegueira" Retrô)
    addRoad(enter: 40, hold: 60, leave: 40, curve: 0, y: 35);

    // 4. Descida com Curva em S à Esquerda
    addRoad(enter: 30, hold: 40, leave: 30, curve: -3.0, y: -35);

    // 5. Chicane Rápida (Direita -> Esquerda)
    addRoad(enter: 20, hold: 25, leave: 20, curve: 3.5, y: 10);
    addRoad(enter: 20, hold: 25, leave: 20, curve: -3.5, y: -10);

    // 6. Grande Reta do NITRO (Velocidade Máxima!)
    addRoad(enter: 25, hold: 100, leave: 25, curve: 0, y: 0);

    // 7. Curva Longa e Rápida à Esquerda
    addRoad(enter: 40, hold: 70, leave: 40, curve: -2.5, y: 15);

    // 8. Reta Final com Ondulação Suave até a Chegada
    addRoad(enter: 30, hold: 60, leave: 30, curve: 0, y: -15);
    addRoad(enter: 20, hold: 30, leave: 20, curve: 0, y: 0);

    // Adiciona Itens de Cenário (Palmeiras, Placas e Outdoors)
    for (int i = 20; i < segments.length; i += 12) {
      // Palmeiras alternadas dos dois lados
      outScenery.add(SceneryItem(
        segmentIndex: i,
        offset: (i % 24 == 0) ? -1.6 : 1.6,
        type: SceneryType.palmTree,
      ));

      // Placas de Curva
      if (i > 80 && i < 150 && i % 36 == 0) {
        outScenery.add(SceneryItem(
          segmentIndex: i,
          offset: -1.3,
          type: SceneryType.retroSign,
          text: 'TURBO ZONE',
        ));
      }

      // Outdoors de Corrida dos Anos 90
      if (i > 300 && i < 400 && i % 48 == 0) {
        outScenery.add(SceneryItem(
          segmentIndex: i,
          offset: 1.4,
          type: SceneryType.billboard,
          text: 'TOP SPEED 90s',
        ));
      }
    }

    // Adiciona Carros Rivais bem distribuídos nas 3 faixas da pista
    final rivalColors = [
      const Color(0xFF00E5FF), // Ciano Elétrico
      const Color(0xFFFFD600), // Amarelo Corrida
      const Color(0xFFE040FB), // Magenta Neon
      const Color(0xFFFFFFFF), // Branco Pérola
      const Color(0xFF00E676), // Verde Lima
    ];

    // Faixas clássicas arcade: Esquerda (-0.55), Centro (0.0), Direita (0.55)
    final lanes = [-0.55, 0.0, 0.55];

    final rng = math.Random(42);
    // Grid de largada e distribuição contínua de rivais ao longo da pista
    final initialOffsets = [
      25.0, 45.0, 70.0, 105.0, 145.0, 190.0, 240.0, 295.0,
      355.0, 420.0, 490.0, 565.0, 645.0, 725.0, 810.0, 895.0, 975.0, 1050.0
    ];

    for (int i = 0; i < initialOffsets.length; i++) {
      final segZ = initialOffsets[i] * segmentLength;
      final lane = lanes[i % lanes.length];
      outTraffic.add(TrafficCar(
        z: segZ,
        offset: lane,
        speed: 9200.0 + (rng.nextDouble() * 3200.0), // ~165 a 210 km/h
        color: rivalColors[i % rivalColors.length],
      ));
    }

    return segments;
  }

  static double _easeIn(double t) => t * t;
  static double _easeInOut(double a, double b, double t) {
    final eased = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
    return a + (b - a) * eased;
  }
}
