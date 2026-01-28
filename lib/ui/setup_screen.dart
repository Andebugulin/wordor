import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/deepl_service.dart';
import '../services/gemini_service.dart';
import '../providers/app_providers.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _deeplController = TextEditingController();
  final _geminiController = TextEditingController();
  bool _isValidating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _deeplController.dispose();
    _geminiController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKeys() async {
    final deeplKey = _deeplController.text.trim();

    if (deeplKey.isEmpty) {
      setState(() => _errorMessage = 'DeepL API key is required');
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      // Validate DeepL key
      final deeplService = DeepLService(deeplKey);
      final isDeeplValid = await deeplService.validateApiKey();

      if (!mounted) return;

      if (!isDeeplValid) {
        setState(() {
          _errorMessage = 'Invalid DeepL API key';
          _isValidating = false;
        });
        return;
      }

      final storage = ref.read(apiKeyStorageProvider);
      await storage.saveApiKey(deeplKey);

      // Optionally save Gemini key if provided
      final geminiKey = _geminiController.text.trim();
      if (geminiKey.isNotEmpty) {
        final geminiService = GeminiService(geminiKey);
        final validation = await geminiService.validateApiKey();

        if (validation['valid']) {
          await storage.saveGeminiApiKey(geminiKey);
        }
      }

      ref.invalidate(apiKeyProvider);
      ref.invalidate(geminiApiKeyProvider);
    } catch (e) {
      setState(() => _errorMessage = 'Connection failed');
    } finally {
      if (mounted) {
        setState(() => _isValidating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Word Recall',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Remember words effortlessly',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 48),

                // DeepL API Key
                Text(
                  'DeepL API Key',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Required for translation',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _deeplController,
                  decoration: InputDecoration(
                    hintText: 'Enter DeepL API key',
                    errorText: _errorMessage,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  obscureText: true,
                  onSubmitted: (_) => _saveApiKeys(),
                ),
                const SizedBox(height: 32),

                // Gemini API Key (Optional)
                Row(
                  children: [
                    Text(
                      'Gemini API Key',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Optional',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'For AI-powered hints (100% free at ai.google.dev)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _geminiController,
                  decoration: const InputDecoration(
                    hintText: 'Enter Gemini API key (optional)',
                    contentPadding: EdgeInsets.all(20),
                  ),
                  obscureText: true,
                  onSubmitted: (_) => _saveApiKeys(),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isValidating ? null : _saveApiKeys,
                    child: _isValidating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Continue'),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'Get DeepL API key →',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'Get FREE Gemini API key →',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
