import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

typedef OnSteeringCallback = void Function(double steeringAngle);

class MotionSensorManager {
  final OnSteeringCallback onSteeringChanged;
  double _filteredSteering = 0.0;
  bool _isListening = false;
  bool isInverted = false;
  Timer? _safariPollTimer;
  String debugText = '0°';

  MotionSensorManager({required this.onSteeringChanged});

  bool get isListening => _isListening;

  Future<bool> requestAndStart() async {
    _startListening();

    try {
      final jsWindow = web.window as JSObject;
      if (jsWindow.hasProperty('requestSafariGyro'.toJS).toDart) {
        jsWindow.callMethod('requestSafariGyro'.toJS);
      }
    } catch (_) {}

    return true;
  }

  void _startListening() {
    if (_isListening) return;
    _isListening = true;

    // Polling dos dados filtrados anti-jitter
    _safariPollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      try {
        final jsWindow = web.window as JSObject;
        if (jsWindow.hasProperty('safariSteering'.toJS).toDart) {
          final s = (jsWindow.getProperty('safariSteering'.toJS) as JSNumber).toDartDouble;
          
          double target = isInverted ? -s : s;

          // Arredonda para exibição limpa sem tremer
          final deg = (target * 24.0).round();
          debugText = '$deg°';

          // Suavização sedosa
          _filteredSteering = _filteredSteering * 0.7 + target * 0.3;
          onSteeringChanged(_filteredSteering);
        }
      } catch (_) {}
    });
  }

  void setManualSteering(double value) {
    _filteredSteering = (isInverted ? -value : value).clamp(-1.0, 1.0);
    onSteeringChanged(_filteredSteering);
  }

  void calibrateZero() {
    try {
      final jsWindow = web.window as JSObject;
      if (jsWindow.hasProperty('calibrateZeroMotion'.toJS).toDart) {
        jsWindow.callMethod('calibrateZeroMotion'.toJS);
      }
    } catch (_) {}
    _filteredSteering = 0.0;
    debugText = '0°';
    onSteeringChanged(0.0);
  }

  void toggleInvert() {
    isInverted = !isInverted;
  }

  void triggerVibration(int durationMs) {
    try {
      web.window.navigator.vibrate(durationMs.toJS);
    } catch (_) {}
  }

  void dispose() {
    _safariPollTimer?.cancel();
  }
}
