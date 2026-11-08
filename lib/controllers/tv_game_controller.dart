import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../core/network/webrtc_manager.dart';
import '../core/platform/platform_helper.dart';
import '../game/engine/racing_game_engine.dart';
import '../game/game_audio.dart';

/// Presentation & Application controller managing the Smart TV game session,
/// WebRTC signaling, audio lifecycle, and game physics orchestration.
class TvGameController extends ChangeNotifier {
  final String roomCode;
  final GameAudio audio;
  late final RacingGameEngine engine;
  late final WebRtcManager _net;

  // Estado de Rede & Sessão
  String connectionStatus = 'Aguardando Volante...';
  bool isControllerConnected = false;
  int latencyMs = 0;
  String qrUrl = '';
  bool _isDisposed = false;

  TvGameController({
    required this.roomCode,
    GameAudio? gameAudio,
    RacingGameEngine? gameEngine,
  }) : audio = gameAudio ?? GameAudio() {
    engine = gameEngine ??
        RacingGameEngine(
          onEngineStart: () => audio.startEngine(),
          onEnginePitchUpdate: (speedRatio, rpmRatio) =>
              audio.updateEnginePitch(speedRatio, rpmRatio),
          onCountdownBeep: (isGo) => audio.playCountdownBeep(isGo: isGo),
          onTireScreech: () => audio.playTireScreech(),
          onNitroSound: () => audio.playNitroSound(),
          onCrashSound: () => audio.playCrashSound(),
        );
  }

  void initialize() {
    // Monta a URL de pareamento para o celular (porta 8443 com HTTPS para Safari/iOS giroscópio)
    final hostname = PlatformHelper.getBrowserHostname();
    qrUrl = 'https://$hostname:8443/?role=controller&room=$roomCode';

    // Inicia e conecta a camada de rede
    _net = WebRtcManager(
      role: 'tv',
      roomCode: roomCode,
      onStatusChanged: (status) {
        if (_isDisposed) return;
        connectionStatus = status;
        notifyListeners();
      },
      onPeerPresenceChanged: (connected) {
        if (_isDisposed) return;
        isControllerConnected = connected;
        notifyListeners();
      },
      onInputReceived: (input, latency) {
        if (_isDisposed) return;
        latencyMs = latency;
        isControllerConnected = true;
        engine.updateInput(
          steering: input.steering,
          throttle: input.throttle,
          brake: input.brake,
          nitro: input.nitro,
        );
        notifyListeners();
      },
    );

    _net.connect();
  }

  /// Chamado pelo Ticker da View a cada frame de renderização (60 FPS)
  void onTick(double dt) {
    if (_isDisposed) return;
    engine.update(dt);
    notifyListeners();
  }

  /// Dispara a largada manualmente ou via comando
  void startCountdown() {
    engine.startCountdown();
    notifyListeners();
  }

  /// Alterna o protocolo do QR Code entre HTTPS (Safari iOS 8443) e HTTP (Android/Padrão 8080)
  void toggleQrProtocol() {
    final isHttps = qrUrl.startsWith('https:');
    final hostname = PlatformHelper.getBrowserHostname();
    qrUrl = isHttps
        ? 'http://$hostname:8080/?role=controller&room=$roomCode'
        : 'https://$hostname:8443/?role=controller&room=$roomCode';
    notifyListeners();
  }

  /// Trata teclas do teclado (suporte para Mac/PC)
  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.keyW) {
        engine.updateInput(throttle: true);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.keyS) {
        engine.updateInput(brake: true);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.keyA) {
        engine.updateInput(steering: -0.8);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.keyD) {
        engine.updateInput(steering: 0.8);
      } else if (event.logicalKey == LogicalKeyboardKey.space) {
        engine.updateInput(nitro: true);
      } else if (event.logicalKey == LogicalKeyboardKey.enter && !engine.raceStarted) {
        startCountdown();
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.keyW) {
        engine.updateInput(throttle: false);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.keyS) {
        engine.updateInput(brake: false);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.keyA ||
          event.logicalKey == LogicalKeyboardKey.keyD) {
        engine.updateInput(steering: 0.0);
      } else if (event.logicalKey == LogicalKeyboardKey.space) {
        engine.updateInput(nitro: false);
      }
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _net.dispose();
    audio.dispose();
    engine.dispose();
    super.dispose();
  }
}
