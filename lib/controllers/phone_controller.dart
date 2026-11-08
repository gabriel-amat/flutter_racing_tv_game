import 'dart:async';
import 'package:flutter/foundation.dart';
import 'motion_sensor_manager.dart';
import '../models/control_input.dart';
import '../network/webrtc_manager.dart';

/// Presentation & Application controller managing the smartphone game controller,
/// motion gyroscope sensors, and high-frequency WebRTC input stream (60 FPS).
class PhoneController extends ChangeNotifier {
  final String roomCode;
  late final WebRtcManager _net;
  late final MotionSensorManager _sensors;

  // Estado dos Comandos
  double currentSteering = 0.0;
  bool isThrottle = false;
  bool isBrake = false;
  bool isNitro = false;

  // Estado da Conexão
  String status = 'Conectando à TV...';
  int latency = 0;
  Timer? _inputLoopTimer;
  bool _isDisposed = false;

  PhoneController({required this.roomCode});

  bool get isConnected => status.contains('TV') || status.contains('CONECTADO');
  String get debugSensorText => _sensors.debugText;
  bool get isInverted => _sensors.isInverted;

  void initialize() {
    _sensors = MotionSensorManager(
      onSteeringChanged: (steering) {
        if (_isDisposed) return;
        currentSteering = steering;
        notifyListeners();
      },
    );

    _net = WebRtcManager(
      role: 'controller',
      roomCode: roomCode,
      onStatusChanged: (newStatus) {
        if (_isDisposed) return;
        status = newStatus;
        notifyListeners();
      },
      onInputReceived: (input, lat) {
        if (_isDisposed) return;
        latency = lat;
        notifyListeners();
      },
    );

    _net.connect();

    // Loop contínuo a ~60 FPS (16ms) para transmissão de ultra-baixa latência
    _inputLoopTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _sendCurrentInput();
    });

    _activateSensors();
  }

  void _activateSensors() async {
    await _sensors.requestAndStart();
    _sensors.calibrateZero();
    if (!_isDisposed) notifyListeners();
  }

  void _sendCurrentInput() {
    if (_isDisposed) return;
    final input = ControlInput(
      steering: currentSteering,
      throttle: isThrottle,
      brake: isBrake,
      nitro: isNitro,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _net.sendInput(input);
  }

  void setThrottle(bool value) {
    if (isThrottle == value) return;
    isThrottle = value;
    notifyListeners();
  }

  void setBrake(bool value) {
    if (isBrake == value) return;
    isBrake = value;
    notifyListeners();
  }

  void setNitro(bool value) {
    if (isNitro == value) return;
    isNitro = value;
    notifyListeners();
  }

  void setManualSteering(double value) {
    _sensors.setManualSteering(value);
  }

  void calibrateZero() {
    _sensors.calibrateZero();
    _sensors.triggerVibration(40);
    notifyListeners();
  }

  void toggleInvert() {
    _sensors.toggleInvert();
    _sensors.triggerVibration(30);
    notifyListeners();
  }

  void triggerHaptic(int durationMs) {
    _sensors.triggerVibration(durationMs);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _inputLoopTimer?.cancel();
    _sensors.dispose();
    _net.dispose();
    super.dispose();
  }
}
