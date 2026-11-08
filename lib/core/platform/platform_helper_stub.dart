/// Stub implementation for non-web environments (such as unit tests or VM).
class PlatformHelper {
  static String getBrowserUrl() => 'http://127.0.0.1:8080/';

  static String getBrowserHost() => '127.0.0.1:8080';

  static String getBrowserHostname() => '127.0.0.1';

  static bool isHttps() => false;
}
