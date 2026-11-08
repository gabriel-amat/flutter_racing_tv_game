import 'package:web/web.dart' as web;

/// Web implementation querying the browser DOM.
class PlatformHelper {
  static String getBrowserUrl() {
    try {
      return web.window.location.href;
    } catch (_) {
      return 'http://127.0.0.1:8080/';
    }
  }

  static String getBrowserHost() {
    try {
      if (web.window.location.host.isNotEmpty) {
        return web.window.location.host;
      }
    } catch (_) {}
    return 'localhost:8080';
  }

  static String getBrowserHostname() {
    try {
      if (web.window.location.hostname.isNotEmpty) {
        return web.window.location.hostname;
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  static bool isHttps() {
    try {
      return web.window.location.protocol == 'https:';
    } catch (_) {
      return false;
    }
  }
}
