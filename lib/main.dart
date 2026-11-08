import 'package:flutter/material.dart';
import 'core/platform/platform_helper.dart';
import 'screens/phone_controller_screen.dart';
import 'screens/tv_game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RetroRacingApp());
}

class RetroRacingApp extends StatelessWidget {
  const RetroRacingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retro Racing TV - 90s Arcade',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFCC),
          secondary: Color(0xFFFF007F),
        ),
      ),
      home: const AppRouter(),
    );
  }
}

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    String? role;
    String room = 'RACE';

    try {
      final uri = Uri.parse(PlatformHelper.getBrowserUrl());

      // Checa query params da URL (?role=controller&room=XXXX)
      role = uri.queryParameters['role'];
      if (uri.queryParameters.containsKey('room')) {
        room = uri.queryParameters['room']!.toUpperCase();
      }

      // Checa fragmento (#/controller?room=XXXX)
      if (uri.hasFragment) {
        final fragUri = Uri.parse(
          uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}',
        );
        if (fragUri.path.contains('controller')) {
          role = 'controller';
        }
        if (fragUri.queryParameters.containsKey('room')) {
          room = fragUri.queryParameters['room']!.toUpperCase();
        }
      }
    } catch (_) {}

    // Se a URL indicar role=controller OU for uma tela de smartphone, abre o Volante direto!
    final size = MediaQuery.of(context).size;
    final isMobileScreen = size.shortestSide < 650;

    if (role == 'controller' || isMobileScreen) {
      return PhoneControllerScreen(roomCode: room);
    }

    // Por padrão (TV ou Desktop/Notebook com tela grande), abre o Jogo em Tela Cheia
    return TvGameScreen(initialRoomCode: room);
  }
}
