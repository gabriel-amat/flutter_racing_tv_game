import 'dart:ui';

class WorldPoint {
  double x;
  double y;
  double z;

  WorldPoint({this.x = 0, this.y = 0, this.z = 0});
}

class ScreenPoint {
  double x;
  double y;
  double w;
  double scale;

  ScreenPoint({this.x = 0, this.y = 0, this.w = 0, this.scale = 0});
}

class RoadPoint {
  final WorldPoint world;
  final ScreenPoint screen;

  RoadPoint({required this.world, required this.screen});

  void project({
    required double cameraX,
    required double cameraY,
    required double cameraZ,
    required double cameraDepth,
    required double screenWidth,
    required double screenHeight,
    required double roadWidth,
  }) {
    final relZ = world.z - cameraZ;
    if (relZ <= 0) {
      screen.scale = 0;
      return;
    }

    screen.scale = cameraDepth / relZ;
    screen.x = (screenWidth / 2) + (screen.scale * (world.x - cameraX) * (screenWidth / 2));
    screen.y = (screenHeight / 2) - (screen.scale * (world.y - cameraY) * (screenHeight / 2));
    screen.w = screen.scale * roadWidth * (screenWidth / 2);
  }
}

class RoadColors {
  final Color grass;
  final Color rumble;
  final Color road;
  final Color? lane;

  const RoadColors({
    required this.grass,
    required this.rumble,
    required this.road,
    this.lane,
  });
}

class RoadSegment {
  final int index;
  final RoadPoint p1;
  final RoadPoint p2;
  final double curve;
  final RoadColors colors;
  double clipY = 0;
  bool isVisible = true;

  RoadSegment({
    required this.index,
    required this.p1,
    required this.p2,
    required this.curve,
    required this.colors,
  });
}
