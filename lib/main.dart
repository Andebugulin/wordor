import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/notification_service.dart';
import 'ui/home_screen.dart';
import 'ui/setup_screen.dart';
import 'providers/app_providers.dart';
import 'theme.dart';

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

    return MaterialApp(
      title: 'Wordor',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: apiKeyAsync.when(
        data: (apiKey) =>
            apiKey != null ? const HomeScreen() : const SetupScreen(),
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stack) =>
            Scaffold(body: Center(child: Text('Error: $error'))),
      ),
    );
  }
}
