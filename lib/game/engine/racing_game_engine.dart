import 'dart:async';
import 'dart:math' as math;
import '../models/road_segment.dart';
import '../models/traffic_and_scenery.dart';
import '../track_builder.dart';

/// Pure game domain engine responsible for track simulation, arcade physics,
/// countdown lifecycle, and collision detection.
class RacingGameEngine {
  // Configurações de Física
  static const double maxSpeed = 24000.0; // ~280 km/h
  static const double nitroSpeed = 30000.0; // ~350 km/h
  static const double accel = 7000.0;
  static const double braking = 12000.0;
  static const double decel = 2500.0;
  static const double offRoadDecel = 9000.0;
  static const double offRoadMaxSpeed = 6800.0; // ~80 km/h

  // Geometria da Pista e Cenário
  late final List<RoadSegment> segments;
  final List<SceneryItem> scenery = [];
  final List<TrafficCar> traffic = [];
  late final double trackLength;

  // Estado da Corrida e Física do Jogador
  double position = 0.0;
  double playerX = 0.0;
  double speed = 0.0;
  double collisionCooldown = 0.0;
  int currentLap = 1;
  double lapTime = 0.0;

  // Estado da Largada
  int countdown = 0; // 0 = inativo/largado, 3, 2, 1 = contagem regressiva
  bool raceStarted = false;
  Timer? _countdownTimer;

  // Inputs Atuais
  double steering = 0.0;
  bool throttle = false;
  bool brake = false;
  bool nitro = false;

  // Callbacks de Áudio Desacoplados
  void Function()? onEngineStart;
  void Function(double speedRatio, double rpmRatio)? onEnginePitchUpdate;
  void Function(bool isGo)? onCountdownBeep;
  void Function()? onTireScreech;
  void Function()? onNitroSound;
  void Function()? onCrashSound;

  RacingGameEngine({
    this.onEngineStart,
    this.onEnginePitchUpdate,
    this.onCountdownBeep,
    this.onTireScreech,
    this.onNitroSound,
    this.onCrashSound,
  }) {
    _initTrack();
  }

  void _initTrack() {
    segments = TrackBuilder.buildTrack(
      outScenery: scenery,
      outTraffic: traffic,
    );
    trackLength = segments.length * TrackBuilder.segmentLength;
  }

  /// Inicia a contagem regressiva da largada (3, 2, 1, GO!)
  void startCountdown() {
    if (raceStarted || countdown > 0) return;

    countdown = 3;
    onEngineStart?.call();
    onCountdownBeep?.call(false);

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      countdown--;
      if (countdown > 0) {
        onCountdownBeep?.call(false);
      } else if (countdown == 0) {
        onCountdownBeep?.call(true);
        raceStarted = true;
        timer.cancel();
      }
    });
  }

  /// Atualiza os inputs do jogador vindos da rede ou do teclado
  void updateInput({
    double? steering,
    bool? throttle,
    bool? brake,
    bool? nitro,
  }) {
    if (steering != null) this.steering = steering;
    if (throttle != null) this.throttle = throttle;
    if (brake != null) this.brake = brake;
    if (nitro != null) this.nitro = nitro;

    // Se o jogador pisou no acelerador e ainda não iniciou a largada, dispara o countdown!
    if (!raceStarted && countdown == 0 && this.throttle) {
      startCountdown();
    }
  }

  /// Game loop executado a cada tick com delta time (dt)
  void update(double dt) {
    if (dt <= 0 || dt > 0.1) return;

    if (!raceStarted) return;

    lapTime += dt;
    if (collisionCooldown > 0) {
      collisionCooldown -= dt;
    }

    final currentMaxSpeed = nitro ? nitroSpeed : maxSpeed;
    final isOffRoad = playerX < -1.0 || playerX > 1.0;
    final targetMaxSpeed = isOffRoad ? math.min(currentMaxSpeed, offRoadMaxSpeed) : currentMaxSpeed;

    // 1. Aceleração, Nitro e Frenagem
    if (throttle) {
      if (nitro && !isOffRoad) {
        speed += accel * 1.8 * dt;
        onNitroSound?.call();
      } else {
        speed += accel * dt;
      }
    } else if (brake) {
      speed -= braking * dt;
    } else {
      speed -= decel * dt;
    }

    // 2. Atrito de grama/fora de pista
    if (isOffRoad) {
      if (speed > targetMaxSpeed) {
        speed -= offRoadDecel * dt;
        if (speed > 4000) {
          onTireScreech?.call();
        }
      }
    }

    speed = speed.clamp(0.0, targetMaxSpeed);

    // 3. Posição ao longo da pista e voltas
    position += speed * dt;
    while (position >= trackLength) {
      position -= trackLength;
      currentLap++;
      lapTime = 0.0;
    }

    // 4. Curvatura da Pista e Força Centrífuga
    final currentSegIndex = ((position / TrackBuilder.segmentLength).floor() % segments.length);
    final currentSegment = segments[currentSegIndex];
    final speedRatio = speed / maxSpeed;

    // Efeito da curva empurrando o carro
    playerX -= (speedRatio * currentSegment.curve * 0.02 * dt);

    // Esterçamento pelo volante com sensibilidade dinâmica
    final effectiveSteerRatio = math.max(0.24, speedRatio);
    playerX += (steering * effectiveSteerRatio * 1.8 * dt);
    playerX = playerX.clamp(-2.0, 2.0);

    // 5. Atualização de Áudio do Motor
    final rpmRatio = (speedRatio * 1.15).clamp(0.1, 1.0);
    onEnginePitchUpdate?.call(speedRatio, rpmRatio);

    // 6. Atualização e Colisão com Carros de Tráfego Rival
    _updateTraffic(dt, targetMaxSpeed);
  }

  void _updateTraffic(double dt, double targetMaxSpeed) {
    for (var car in traffic) {
      car.z += car.speed * dt;
      while (car.z >= trackLength) {
        car.z -= trackLength;
      }

      final distZ = (car.z - position).abs();
      if (distZ < 130) {
        final distX = (car.offset - playerX).abs();
        if (distX < 0.22) {
          if (distX > 0.14) {
            // Raspão lateral esportivo
            playerX += (playerX > car.offset ? 0.06 : -0.06);
            if (collisionCooldown <= 0) {
              speed = (speed * 0.94).clamp(0.0, targetMaxSpeed);
              onTireScreech?.call();
              collisionCooldown = 0.3;
            }
          } else {
            // Batida traseira direta
            if (collisionCooldown <= 0) {
              speed = math.max(speed * 0.80, 5000.0).clamp(0.0, targetMaxSpeed);
              playerX += (playerX > car.offset ? 0.05 : -0.05);
              car.speed += 3500.0;
              onCrashSound?.call();
              collisionCooldown = 0.6;
            }
          }
        }
      }
    }
  }

  void reset() {
    position = 0.0;
    playerX = 0.0;
    speed = 0.0;
    currentLap = 1;
    lapTime = 0.0;
    countdown = 0;
    raceStarted = false;
    _countdownTimer?.cancel();
  }

  void dispose() {
    _countdownTimer?.cancel();
  }
}
