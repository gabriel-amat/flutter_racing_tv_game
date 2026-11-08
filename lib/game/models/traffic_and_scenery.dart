import 'dart:ui';

class TrafficCar {
  double z;          // posição no mundo (Z ao longo da pista)
  double offset;     // posição lateral (-0.8 a 0.8)
  double speed;      // velocidade própria
  final Color color; // cor retrô do carro
  final double width;
  final double height;

  TrafficCar({
    required this.z,
    required this.offset,
    required this.speed,
    required this.color,
    this.width = 300,
    this.height = 160,
  });
}

enum SceneryType {
  palmTree,
  billboard,
  lightPole,
  retroSign,
}

class SceneryItem {
  final int segmentIndex;
  final double offset; // -1.5 (margem esquerda) ou 1.5 (margem direita)
  final SceneryType type;
  final String? text;

  SceneryItem({
    required this.segmentIndex,
    required this.offset,
    required this.type,
    this.text,
  });
}
