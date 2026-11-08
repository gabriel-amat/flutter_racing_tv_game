import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../core/platform/platform_helper.dart';
import '../models/control_input.dart';

typedef OnInputCallback = void Function(ControlInput input, int latencyMs);
typedef OnStatusCallback = void Function(String status);
typedef OnPeerPresenceCallback = void Function(bool isConnected);

class WebRtcManager {
  final String role; // 'tv' ou 'controller'
  final String roomCode;
  final OnInputCallback? onInputReceived;
  final OnStatusCallback? onStatusChanged;
  final OnPeerPresenceCallback? onPeerPresenceChanged;

  web.WebSocket? _ws;
  web.RTCPeerConnection? _peer;
  web.RTCDataChannel? _dataChannel;
  bool _isDataChannelOpen = false;
  bool _isConnected = false;

  WebRtcManager({
    required this.role,
    required this.roomCode,
    this.onInputReceived,
    this.onStatusChanged,
    this.onPeerPresenceChanged,
  });

  bool get isConnected => _isConnected;
  bool get isDirectP2P => _isDataChannelOpen;

  void connect() {
    onStatusChanged?.call('Conectando ao servidor...');

    // Descobre o host e protocolo do navegador automaticamente (ex: 192.168.1.76:8080)
    final host = PlatformHelper.getBrowserHost();
    final protocol = PlatformHelper.isHttps() ? 'wss:' : 'ws:';
    final wsUrl = '$protocol//$host/ws?role=$role&room=$roomCode';

    try {
      _ws = web.WebSocket(wsUrl);

      _ws!.onopen = (web.Event e) {
        _isConnected = true;
        onStatusChanged?.call(role == 'tv' ? 'Aguardando Piloto...' : 'Conectado à TV!');
      }.toJS;

      _ws!.onmessage = (web.MessageEvent e) {
        final rawData = e.data.toString();
        try {
          final data = jsonDecode(rawData) as Map<String, dynamic>;
          _handleMessage(data);
        } catch (_) {}
      }.toJS;

      _ws!.onclose = (web.CloseEvent e) {
        _isConnected = false;
        _isDataChannelOpen = false;
        onStatusChanged?.call('Desconectado');
      }.toJS;

      _ws!.onerror = (web.Event e) {
        onStatusChanged?.call('Erro de Conexão');
      }.toJS;
    } catch (e) {
      onStatusChanged?.call('Falha ao conectar: $e');
    }
  }

  void _setupWebRtcPeer() {
    try {
      final config = web.RTCConfiguration(
        iceServers: [
          web.RTCIceServer(urls: 'stun:stun.l.google.com:19302'.toJS),
        ].toJS,
      );

      _peer = web.RTCPeerConnection(config);

      _peer!.onicecandidate = (web.RTCPeerConnectionIceEvent e) {
        if (e.candidate != null) {
          _sendSignal({
            'type': 'candidate',
            'candidate': e.candidate!.candidate,
            'sdpMid': e.candidate!.sdpMid,
            'sdpMLineIndex': e.candidate!.sdpMLineIndex,
          });
        }
      }.toJS;

      if (role == 'tv') {
        // A TV cria o canal de dados P2P com UDP rápido
        final dcInit = web.RTCDataChannelInit(
          ordered: false,
          maxRetransmits: 0,
        );
        _dataChannel = _peer!.createDataChannel('controls', dcInit);
        _bindDataChannel(_dataChannel!);
      } else {
        // O controle recebe o canal de dados criado pela TV
        _peer!.ondatachannel = (web.RTCDataChannelEvent e) {
          _dataChannel = e.channel;
          _bindDataChannel(_dataChannel!);
        }.toJS;
      }
    } catch (_) {}
  }

  void _bindDataChannel(web.RTCDataChannel dc) {
    dc.onopen = (web.Event e) {
      _isDataChannelOpen = true;
      onStatusChanged?.call('🎮 P2P DIRETO CONECTADO');
    }.toJS;

    dc.onclose = (web.Event e) {
      _isDataChannelOpen = false;
    }.toJS;

    dc.onmessage = (web.MessageEvent e) {
      try {
        final data = jsonDecode(e.data.toString()) as Map<String, dynamic>;
        onPeerPresenceChanged?.call(true);
        _processInput(data);
      } catch (_) {}
    }.toJS;
  }

  void _handleMessage(Map<String, dynamic> data) async {
    final type = data['type'];

    if (type == 'room_created' && role == 'tv') {
      if (data['hasController'] == true) {
        onStatusChanged?.call('📱 Piloto Conectado!');
        onPeerPresenceChanged?.call(true);
        _setupWebRtcPeer();

        final offer = await _peer!.createOffer().toDart;
        if (offer != null) {
          final localDesc = web.RTCLocalSessionDescriptionInit(
            type: offer.type,
            sdp: offer.sdp,
          );
          await _peer!.setLocalDescription(localDesc).toDart;

          _sendSignal({
            'type': 'offer',
            'sdp': offer.sdp,
          });
        }
      }
    } else if (type == 'controller_joined' && role == 'tv') {
      onStatusChanged?.call('📱 Piloto Conectado!');
      onPeerPresenceChanged?.call(true);
      _setupWebRtcPeer();
      
      // Cria a oferta WebRTC
      final offer = await _peer!.createOffer().toDart;
      if (offer != null) {
        final localDesc = web.RTCLocalSessionDescriptionInit(
          type: offer.type,
          sdp: offer.sdp,
        );
        await _peer!.setLocalDescription(localDesc).toDart;

        _sendSignal({
          'type': 'offer',
          'sdp': offer.sdp,
        });
      }
    } else if (type == 'controller_disconnected' && role == 'tv') {
      onStatusChanged?.call('Aguardando Piloto...');
      onPeerPresenceChanged?.call(false);
    } else if (type == 'tv_disconnected' && role == 'controller') {
      onStatusChanged?.call('TV Desconectada');
      onPeerPresenceChanged?.call(false);
    } else if (type == 'offer' && role == 'controller') {
      _setupWebRtcPeer();
      
      final desc = web.RTCSessionDescriptionInit(
        type: 'offer',
        sdp: data['sdp'] as String,
      );
      await _peer!.setRemoteDescription(desc).toDart;

      final answer = await _peer!.createAnswer().toDart;
      if (answer != null) {
        final localAnswer = web.RTCLocalSessionDescriptionInit(
          type: answer.type,
          sdp: answer.sdp,
        );
        await _peer!.setLocalDescription(localAnswer).toDart;

        _sendSignal({
          'type': 'answer',
          'sdp': answer.sdp,
        });
      }
    } else if (type == 'answer' && role == 'tv') {
      final desc = web.RTCSessionDescriptionInit(
        type: 'answer',
        sdp: data['sdp'] as String,
      );
      await _peer!.setRemoteDescription(desc).toDart;
    } else if (type == 'candidate') {
      try {
        final candidateInit = web.RTCIceCandidateInit(
          candidate: data['candidate'] as String,
          sdpMid: data['sdpMid'] as String?,
          sdpMLineIndex: data['sdpMLineIndex'] as int?,
        );
        await _peer!.addIceCandidate(candidateInit).toDart;
      } catch (_) {}
    } else if (type == 'input') {
      // Fallback via WebSocket: se o DataChannel ainda estiver negociando,
      // os comandos de direção já chegam com latência imperceptível!
      onPeerPresenceChanged?.call(true);
      _processInput(data);
    }
  }

  void _processInput(Map<String, dynamic> data) {
    final input = ControlInput.fromJson(data);
    final now = DateTime.now().millisecondsSinceEpoch;
    final latency = (now - input.timestamp).clamp(0, 999);
    onInputReceived?.call(input, latency);
  }

  void sendInput(ControlInput input) {
    final payload = jsonEncode(input.toJson());

    // Se o DataChannel P2P direto estiver aberto, manda por ele (latência ~2ms)
    if (_isDataChannelOpen && _dataChannel?.readyState == 'open') {
      try {
        _dataChannel!.send(payload.toJS);
        return;
      } catch (_) {}
    }

    // Fallback: se o DataChannel ainda estiver conectando, manda pelo WebSocket
    if (_ws?.readyState == web.WebSocket.OPEN) {
      try {
        _ws!.send(payload.toJS);
      } catch (_) {}
    }
  }

  void _sendSignal(Map<String, dynamic> data) {
    if (_ws?.readyState == web.WebSocket.OPEN) {
      _ws!.send(jsonEncode(data).toJS);
    }
  }

  void dispose() {
    try {
      _dataChannel?.close();
      _peer?.close();
      _ws?.close();
    } catch (_) {}
  }
}
