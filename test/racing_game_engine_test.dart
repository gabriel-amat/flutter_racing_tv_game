import 'package:flutter_test/flutter_test.dart';
import 'package:retro_racing_tv/game/engine/racing_game_engine.dart';
import 'package:retro_racing_tv/models/control_input.dart';

void main() {
  group('ControlInput Serialization Tests', () {
    test('serializes and deserializes correctly', () {
      final input = ControlInput(
        steering: 0.75,
        throttle: true,
        brake: false,
        nitro: true,
        timestamp: 123456789,
      );

      final json = input.toJson();
      expect(json['type'], 'input');
      expect(json['s'], 0.75);
      expect(json['t'], true);
      expect(json['b'], false);
      expect(json['n'], true);
      expect(json['ts'], 123456789);

      final restored = ControlInput.fromJson(json);
      expect(restored.steering, 0.75);
      expect(restored.throttle, true);
      expect(restored.brake, false);
      expect(restored.nitro, true);
      expect(restored.timestamp, 123456789);
    });
  });

  group('RacingGameEngine Physics & Logic Tests', () {
    late RacingGameEngine engine;

    setUp(() {
      engine = RacingGameEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('initializes track with segments, traffic and scenery', () {
      expect(engine.segments.isNotEmpty, isTrue);
      expect(engine.scenery.isNotEmpty, isTrue);
      expect(engine.traffic.isNotEmpty, isTrue);
      expect(engine.trackLength, greaterThan(0));
      expect(engine.speed, 0.0);
      expect(engine.position, 0.0);
      expect(engine.currentLap, 1);
      expect(engine.raceStarted, isFalse);
    });

    test('accelerating before start triggers countdown', () {
      expect(engine.countdown, 0);
      engine.updateInput(throttle: true);
      expect(engine.countdown, 3);
      expect(engine.throttle, isTrue);
    });

    test('physics does not advance before raceStarted is true', () {
      engine.updateInput(throttle: true);
      engine.update(0.016);
      expect(engine.position, 0.0);
      expect(engine.speed, 0.0);
    });

    test('accelerates smoothly once race is started', () {
      engine.raceStarted = true;
      engine.updateInput(throttle: true);

      // Simula 1 segundo a 60 FPS (dt ~ 0.016s)
      for (int i = 0; i < 60; i++) {
        engine.update(1.0 / 60.0);
      }

      expect(engine.speed, greaterThan(5000.0));
      expect(engine.position, greaterThan(0.0));
    });

    test('brakes decelerate the car faster than normal deceleration', () {
      engine.raceStarted = true;
      engine.speed = 10000.0;
      engine.updateInput(throttle: false, brake: true);

      engine.update(0.1);
      expect(engine.speed, lessThan(10000.0));
    });

    test('nitro increases acceleration and max speed limit', () {
      engine.raceStarted = true;
      engine.updateInput(throttle: true, nitro: true);

      for (int i = 0; i < 60; i++) {
        engine.update(1.0 / 60.0);
      }

      expect(engine.speed, greaterThan(10000.0));
    });

    test('steering is clamped within track boundaries', () {
      engine.raceStarted = true;
      engine.speed = 5000.0;
      engine.updateInput(steering: 1.0);

      // Simula direção contínua para a direita
      for (int i = 0; i < 200; i++) {
        engine.update(1.0 / 60.0);
      }

      expect(engine.playerX, lessThanOrEqualTo(2.0));
    });

    test('lap increments when completing the track', () {
      engine.raceStarted = true;
      engine.speed = RacingGameEngine.maxSpeed;
      engine.updateInput(throttle: true);
      final initialLap = engine.currentLap;

      // Avança a posição até ultrapassar o tamanho da pista
      final steps = (engine.trackLength / (RacingGameEngine.maxSpeed * 0.05)).ceil() + 10;
      for (int i = 0; i < steps; i++) {
        engine.update(0.05);
      }

      expect(engine.currentLap, greaterThan(initialLap));
    });
  });
}
