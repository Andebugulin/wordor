import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/notification_service.dart';
import 'ui/home_screen.dart';
import 'ui/setup_screen.dart';
import 'providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.initialize();
  await NotificationService.requestPermissions();

  runApp(const ProviderScope(child: WordRecallApp()));
}

class WordRecallApp extends ConsumerWidget {
  const WordRecallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKeyAsync = ref.watch(apiKeyProvider);
    final themeModeAsync = ref.watch(themeModeProvider);
    final darkTheme = ref.watch(darkThemeProvider);
    final lightTheme = ref.watch(lightThemeProvider);

    return themeModeAsync.when(
      data: (themeMode) => MaterialApp(
        title: 'Wordor',
        theme: lightTheme.themeData,
        darkTheme: darkTheme.themeData,
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        home: apiKeyAsync.when(
          data: (apiKey) =>
              apiKey != null ? const HomeScreen() : const SetupScreen(),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stack) =>
              Scaffold(body: Center(child: Text('Error: $error'))),
        ),
      ),
      loading: () => MaterialApp(
        title: 'Wordor',
        theme: lightTheme.themeData,
        darkTheme: darkTheme.themeData,
        themeMode: ThemeMode.dark,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (_, __) => MaterialApp(
        title: 'Wordor',
        theme: lightTheme.themeData,
        darkTheme: darkTheme.themeData,
        themeMode: ThemeMode.dark,
        debugShowCheckedModeBanner: false,
        home: apiKeyAsync.when(
          data: (apiKey) =>
              apiKey != null ? const HomeScreen() : const SetupScreen(),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stack) =>
              Scaffold(body: Center(child: Text('Error: $error'))),
        ),
      ),
    );
  }
}
