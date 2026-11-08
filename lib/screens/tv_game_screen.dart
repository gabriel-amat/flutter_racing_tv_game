import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../controllers/tv_game_controller.dart';
import '../game/engine/racing_game_engine.dart';
import '../game/retro_painter.dart';

class TvGameScreen extends StatefulWidget {
  final String initialRoomCode;

  const TvGameScreen({super.key, this.initialRoomCode = 'RACE'});

  @override
  State<TvGameScreen> createState() => _TvGameScreenState();
}

class _TvGameScreenState extends State<TvGameScreen>
    with SingleTickerProviderStateMixin {
  late final TvGameController _controller;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = TvGameController(roomCode: widget.initialRoomCode);
    _controller.initialize();

    // Loop de renderização sincronizado com a taxa de atualização da tela (60/120 FPS)
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }

    final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;

    _controller.onTick(dt);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) => _controller.handleKeyEvent(event),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final engine = _controller.engine;

            return Stack(
              children: [
                // Renderizador da Pista em Tela Cheia
                Positioned.fill(
                  child: CustomPaint(
                    painter: RetroPainter(
                      segments: engine.segments,
                      scenery: engine.scenery,
                      traffic: engine.traffic,
                      position: engine.position,
                      playerX: engine.playerX,
                      speed: engine.speed,
                      maxSpeed: engine.nitro ? RacingGameEngine.nitroSpeed : RacingGameEngine.maxSpeed,
                      steering: engine.steering,
                      isThrottle: engine.throttle,
                      isBraking: engine.brake,
                      isNitroActive: engine.nitro,
                      trackLength: engine.trackLength,
                      currentLap: engine.currentLap,
                      lapTime: engine.lapTime,
                      connectionStatus: _controller.connectionStatus,
                      latencyMs: _controller.latencyMs,
                    ),
                  ),
                ),

                // Painel de Conexão com QR Code (Exibido enquanto a corrida não começar)
                if (!engine.raceStarted)
                  Center(
                    child: _buildConnectionLobby(context, engine),
                  ),

                // Contagem Regressiva Arcade (3... 2... 1... GO!)
                if (engine.countdown > 0)
                  Center(
                    child: Text(
                      '${engine.countdown}',
                      style: const TextStyle(
                        color: Color(0xFFFF007F),
                        fontSize: 160,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        shadows: [
                          Shadow(color: Color(0xFF00FFCC), blurRadius: 40),
                          Shadow(color: Colors.black, blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildConnectionLobby(BuildContext context, dynamic engine) {
    final isConnected = _controller.isControllerConnected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F051D).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isConnected ? const Color(0xFF00E676) : const Color(0xFF00FFCC),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: (isConnected ? const Color(0xFF00E676) : const Color(0xFF00FFCC))
                .withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isConnected
                ? '✅ VOLANTE CONECTADO COM SUCESSO!'
                : '🏁 CONECTE SEU CELULAR COMO VOLANTE 🏁',
            style: TextStyle(
              color: isConnected ? const Color(0xFF00E676) : const Color(0xFF00FFCC),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          if (!isConnected) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: _controller.qrUrl,
                version: QrVersions.auto,
                size: 200,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'SALA: ${_controller.roomCode}',
              style: const TextStyle(
                color: Color(0xFFFF007F),
                fontSize: 26,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _controller.qrUrl,
              style: const TextStyle(
                color: Color(0xFF00FFCC),
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () => _controller.toggleQrProtocol(),
                  icon: const Icon(Icons.swap_horiz, size: 16, color: Colors.white70),
                  label: Text(
                    _controller.qrUrl.startsWith('https:')
                        ? 'Mudar QR para HTTP (8080)'
                        : 'Mudar QR para HTTPS (8443 Safari)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Aponte a câmera do seu celular para o QR Code acima\n(No iPhone/Safari, aceite a permissão de movimento ao abrir!)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            ),
          ] else ...[
            const Icon(Icons.sports_esports, size: 72, color: Color(0xFF00E676)),
            const SizedBox(height: 12),
            const Text(
              'PILOTO PRONTO NO GRID!',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '👉 Pise no botão ACELERAR no seu celular para a largada!\n(ou pressione Enter)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF00FFCC),
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _controller.startCountdown(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF007F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('INICIAR CORRIDA AGORA', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            _controller.connectionStatus,
            style: TextStyle(
              color: isConnected ? const Color(0xFF00E676) : Colors.orangeAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
