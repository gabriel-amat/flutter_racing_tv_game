// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

class Room {
  final String code;
  WebSocket? tvSocket;
  WebSocket? controllerSocket;

  Room(this.code);

  bool get isFull => tvSocket != null && controllerSocket != null;
  bool get isEmpty => tvSocket == null && controllerSocket == null;
}

void main(List<String> args) async {
  final httpPort = 8080;
  final httpsPort = 8443;
  final Map<String, Room> rooms = {};

  // Descobre o IP local do Mac
  String localIp = '127.0.0.1';
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (!addr.isLoopback) {
          localIp = addr.address;
          break;
        }
      }
      if (localIp != '127.0.0.1') break;
    }
  } catch (_) {}

  // 1. Inicia Servidor HTTP na porta 8080 (ideal para Smart TVs)
  final httpServer = await HttpServer.bind(InternetAddress.anyIPv4, httpPort);
  _listenRequests(httpServer, rooms);

  // 2. Inicia Servidor HTTPS na porta 8443 se certificados existirem (OBRIGATÓRIO para giroscópio no Safari iOS)
  HttpServer? httpsServer;
  if (await File('cert.pem').exists() && await File('key.pem').exists()) {
    try {
      final secContext = SecurityContext()
        ..useCertificateChain('cert.pem')
        ..usePrivateKey('key.pem');
      httpsServer = await HttpServer.bindSecure(InternetAddress.anyIPv4, httpsPort, secContext);
      _listenRequests(httpsServer, rooms);
    } catch (e) {
      print('Aviso HTTPS: $e');
    }
  }

  print('╔════════════════════════════════════════════════════════════════════╗');
  print('║                 🏁 RETRO RACING TV SERVER 🏁                       ║');
  print('╠════════════════════════════════════════════════════════════════════╣');
  print('║ 📺 NA SMART TV, acesse no navegador:                               ║');
  print('║    👉 http://$localIp:$httpPort                                    ║');
  print('║                                                                    ║');
  if (httpsServer != null) {
  print('║ 📱 NO IPHONE (SAFARI), acesse com HTTPS para o giroscópio:         ║');
  print('║    👉 https://$localIp:$httpsPort/?role=controller&room=RACE       ║');
  print('║    (No Safari, toque em "Avançado -> Continuar para o site")       ║');
  print('║                                                                    ║');
  }
  print('║ 📱 Ou leia o QR Code na TV para conectar automaticamente!          ║');
  print('╚════════════════════════════════════════════════════════════════════╝');
}

void _listenRequests(HttpServer server, Map<String, Room> rooms) async {
  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      _handleWebSocket(request, rooms);
    } else {
      _handleStaticFiles(request);
    }
  }
}

void _handleWebSocket(HttpRequest request, Map<String, Room> rooms) async {
  final uri = request.uri;
  final roomCode = uri.queryParameters['room']?.toUpperCase() ?? 'RACE';
  final role = uri.queryParameters['role'] ?? 'tv';

  try {
    final socket = await WebSocketTransformer.upgrade(request);
    final room = rooms.putIfAbsent(roomCode, () => Room(roomCode));

    if (role == 'tv') {
      room.tvSocket = socket;
      print('[SALA $roomCode] 📺 TV conectada.');
      socket.add(jsonEncode({
        'type': 'room_created',
        'room': roomCode,
        'hasController': room.controllerSocket != null,
      }));
    } else {
      room.controllerSocket = socket;
      print('[SALA $roomCode] 📱 Controle Mobile conectado.');
      socket.add(jsonEncode({
        'type': 'controller_connected',
        'room': roomCode,
      }));

      room.tvSocket?.add(jsonEncode({
        'type': 'controller_joined',
        'room': roomCode,
      }));
    }

    socket.listen(
      (message) {
        if (role == 'controller') {
          room.tvSocket?.add(message);
        } else {
          room.controllerSocket?.add(message);
        }
      },
      onDone: () {
        if (role == 'tv') {
          room.tvSocket = null;
          print('[SALA $roomCode] 📺 TV desconectou.');
          room.controllerSocket?.add(jsonEncode({'type': 'tv_disconnected'}));
        } else {
          room.controllerSocket = null;
          print('[SALA $roomCode] 📱 Controle desconectou.');
          room.tvSocket?.add(jsonEncode({'type': 'controller_disconnected'}));
        }
        if (room.isEmpty) {
          rooms.remove(roomCode);
        }
      },
      onError: (err) {
        print('[SALA $roomCode] Erro no socket: $err');
      },
    );
  } catch (e) {
    print('Erro upgrade websocket: $e');
  }
}

void _handleStaticFiles(HttpRequest request) async {
  final webDir = Directory('build/web');
  var path = request.uri.path;
  if (path == '/' || path.isEmpty) {
    path = '/index.html';
  }

  final file = File('${webDir.path}$path');
  if (await file.exists()) {
    final mimeType = _getMimeType(file.path);
    request.response.headers.contentType = ContentType.parse(mimeType);
    await file.openRead().pipe(request.response);
  } else {
    final indexFile = File('${webDir.path}/index.html');
    if (await indexFile.exists()) {
      request.response.headers.contentType = ContentType.html;
      await indexFile.openRead().pipe(request.response);
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Arquivo nao encontrado.');
      await request.response.close();
    }
  }
}

String _getMimeType(String path) {
  if (path.endsWith('.html')) return 'text/html; charset=utf-8';
  if (path.endsWith('.js')) return 'application/javascript; charset=utf-8';
  if (path.endsWith('.css')) return 'text/css; charset=utf-8';
  if (path.endsWith('.json')) return 'application/json';
  if (path.endsWith('.png')) return 'image/png';
  if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
  if (path.endsWith('.svg')) return 'image/svg+xml';
  if (path.endsWith('.wasm')) return 'application/wasm';
  return 'application/octet-stream';
}
