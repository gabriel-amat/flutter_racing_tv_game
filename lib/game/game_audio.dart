import 'package:web/web.dart' as web;

class GameAudio {
  web.AudioContext? _ctx;
  web.OscillatorNode? _engineOsc;
  web.GainNode? _engineGain;
  bool _initialized = false;
  final bool _muted = false;

  void init() {
    if (_initialized) return;
    try {
      _ctx = web.AudioContext();
      _initialized = true;
    } catch (_) {}
  }

  void startEngine() {
    if (!_initialized || _ctx == null) init();
    if (_ctx == null) return;

    try {
      if (_ctx!.state == 'suspended') {
        _ctx!.resume();
      }

      if (_engineOsc != null) return;

      _engineOsc = _ctx!.createOscillator();
      _engineGain = _ctx!.createGain();

      _engineOsc!.type = 'sawtooth';
      _engineOsc!.frequency.setValueAtTime(45, _ctx!.currentTime);
      _engineGain!.gain.setValueAtTime(0.08, _ctx!.currentTime);

      _engineOsc!.connect(_engineGain!);
      _engineGain!.connect(_ctx!.destination);
      _engineOsc!.start();
    } catch (_) {}
  }

  void updateEnginePitch(double speedRatio, double rpmRatio) {
    if (_engineOsc == null || _ctx == null) return;
    try {
      // Modula a frequência de 45Hz (marcha lenta) até 260Hz (alta velocidade)
      final freq = 45.0 + (rpmRatio * 180.0) + (speedRatio * 50.0);
      _engineOsc!.frequency.setValueAtTime(freq, _ctx!.currentTime);
      
      final gain = _muted ? 0.0 : (0.05 + (rpmRatio * 0.08));
      _engineGain!.gain.setValueAtTime(gain, _ctx!.currentTime);
    } catch (_) {}
  }

  void playTireScreech() {
    if (_ctx == null || _muted) return;
    try {
      final osc = _ctx!.createOscillator();
      final gain = _ctx!.createGain();

      osc.type = 'triangle';
      osc.frequency.setValueAtTime(800 + (DateTime.now().millisecond % 200), _ctx!.currentTime);

      gain.gain.setValueAtTime(0.12, _ctx!.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, _ctx!.currentTime + 0.15);

      osc.connect(gain);
      gain.connect(_ctx!.destination);

      osc.start();
      osc.stop(_ctx!.currentTime + 0.15);
    } catch (_) {}
  }

  void playNitroSound() {
    if (_ctx == null || _muted) return;
    try {
      final osc = _ctx!.createOscillator();
      final gain = _ctx!.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(300, _ctx!.currentTime);
      osc.frequency.exponentialRampToValueAtTime(1200, _ctx!.currentTime + 0.4);

      gain.gain.setValueAtTime(0.25, _ctx!.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, _ctx!.currentTime + 0.45);

      osc.connect(gain);
      gain.connect(_ctx!.destination);

      osc.start();
      osc.stop(_ctx!.currentTime + 0.45);
    } catch (_) {}
  }

  void playCrashSound() {
    if (_ctx == null || _muted) return;
    try {
      final osc = _ctx!.createOscillator();
      final gain = _ctx!.createGain();

      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(120, _ctx!.currentTime);
      osc.frequency.exponentialRampToValueAtTime(30, _ctx!.currentTime + 0.3);

      gain.gain.setValueAtTime(0.3, _ctx!.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, _ctx!.currentTime + 0.3);

      osc.connect(gain);
      gain.connect(_ctx!.destination);

      osc.start();
      osc.stop(_ctx!.currentTime + 0.3);
    } catch (_) {}
  }

  void playCountdownBeep({bool isGo = false}) {
    if (_ctx == null) init();
    if (_ctx == null || _muted) return;
    try {
      if (_ctx!.state == 'suspended') _ctx!.resume();

      final osc = _ctx!.createOscillator();
      final gain = _ctx!.createGain();

      osc.type = 'square';
      osc.frequency.setValueAtTime(isGo ? 880 : 440, _ctx!.currentTime);

      gain.gain.setValueAtTime(0.2, _ctx!.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, _ctx!.currentTime + (isGo ? 0.5 : 0.25));

      osc.connect(gain);
      gain.connect(_ctx!.destination);

      osc.start();
      osc.stop(_ctx!.currentTime + (isGo ? 0.5 : 0.25));
    } catch (_) {}
  }

  void dispose() {
    try {
      _engineOsc?.stop();
      _engineOsc?.disconnect();
      _ctx?.close();
    } catch (_) {}
  }
}
