import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/jiosaavn_repository.dart';
import 'data/lyrics_repository.dart';
import 'data/music_repository.dart';
import 'state/accent_controller.dart';
import 'state/library_controller.dart';
import 'state/player_controller.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Background playback + lock-screen / notification controls.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.mobilions.music_app.audio',
    androidNotificationChannelName: 'Playback',
    androidNotificationOngoing: true,
  );

  final library = await LibraryController.load();

  runApp(
    MultiProvider(
      providers: [
        // Swap JioSaavnRepository for another MusicRepository to change the
        // music source — no UI changes needed.
        Provider<MusicRepository>(create: (_) => JioSaavnRepository()),
        Provider<LyricsRepository>(create: (_) => LyricsRepository()),
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider(
          create: (_) => PlayerController(onTrackStarted: library.addRecent),
        ),
        // New accent color for every song, taken from its album art.
        ChangeNotifierProvider(
          create: (context) =>
              AccentController(context.read<PlayerController>()),
        ),
      ],
      child: MusicApp(showOnboarding: !library.onboarded),
    ),
  );
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key, required this.showOnboarding});

  final bool showOnboarding;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      scrollBehavior: const _SmoothScrollBehavior(),
      // Cap huge accessibility font sizes so fixed-height rows and cards
      // never overflow, while still honoring the user's setting.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(maxScaleFactor: 1.25),
          ),
          child: child!,
        );
      },
      home: showOnboarding ? const OnboardingScreen() : const HomeShell(),
    );
  }
}

/// Springy iOS-style bounce on every scrollable, on every platform.
class _SmoothScrollBehavior extends MaterialScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
