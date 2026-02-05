import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/deepl_service.dart';
import '../services/ai_hint_service.dart';
import '../providers/app_providers.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _deeplController = TextEditingController();
  final _huggingfaceController = TextEditingController();
  bool _isValidating = false;
  String? _errorMessage;

  // Validation states
  bool? _deeplValid;
  bool? _hfValid;

  @override
  void dispose() {
    _deeplController.dispose();
    _huggingfaceController.dispose();
    super.dispose();
  }

  Future<void> _validateDeepLKey() async {
    final key = _deeplController.text.trim();
    if (key.isEmpty) {
      setState(() => _deeplValid = null);
      return;
    }

    try {
      final service = DeepLService(key);
      final isValid = await service.validateApiKey();
      setState(() => _deeplValid = isValid);
    } catch (e) {
      setState(() => _deeplValid = false);
    }
  }

  Future<void> _validateHFKey() async {
    final key = _huggingfaceController.text.trim();
    if (key.isEmpty) {
      setState(() => _hfValid = null);
      return;
    }

    try {
      final service = AIHintService(key, AIProvider.huggingface);
      final validation = await service.validateApiKey();
      setState(() => _hfValid = validation['valid']);
    } catch (e) {
      setState(() => _hfValid = false);
    }
  }

  Future<void> _saveApiKeys() async {
    final deeplKey = _deeplController.text.trim();

    if (deeplKey.isEmpty) {
      setState(() => _errorMessage = 'DeepL API key is required');
      return;
    }

    if (_deeplValid == false) {
      setState(() => _errorMessage = 'Invalid DeepL API key');
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      // Validate DeepL key if not already validated
      if (_deeplValid == null) {
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
      }

      final storage = ref.read(apiKeyStorageProvider);
      await storage.saveApiKey(deeplKey);

      // Optionally save HuggingFace key if provided and valid
      final huggingfaceKey = _huggingfaceController.text.trim();
      if (huggingfaceKey.isNotEmpty) {
        // Only save if validated or validate now
        if (_hfValid == null) {
          final aiService = AIHintService(
            huggingfaceKey,
            AIProvider.huggingface,
          );
          final validation = await aiService.validateApiKey();
          if (validation['valid']) {
            await storage.saveHuggingFaceApiKey(huggingfaceKey);
          }
        } else if (_hfValid == true) {
          await storage.saveHuggingFaceApiKey(huggingfaceKey);
        }
      }

      ref.invalidate(apiKeyProvider);
      ref.invalidate(huggingfaceApiKeyProvider);
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
                Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    TextField(
                      controller: _deeplController,
                      decoration: InputDecoration(
                        hintText: 'Enter DeepL API key',
                        errorText: _errorMessage,
                        contentPadding: const EdgeInsets.all(20),
                        suffixIcon: _deeplValid == null
                            ? null
                            : Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(
                                  _deeplValid!
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: _deeplValid!
                                      ? const Color(0xFF4ADEAA)
                                      : const Color(0xFFFF6B7A),
                                  size: 24,
                                ),
                              ),
                      ),
                      obscureText: true,
                      onChanged: (value) {
                        setState(() {
                          _deeplValid = null;
                          _errorMessage = null;
                        });
                      },
                      onSubmitted: (_) => _saveApiKeys(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_deeplController.text.isNotEmpty && _deeplValid == null)
                  OutlinedButton(
                    onPressed: _validateDeepLKey,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Validate DeepL Key'),
                  ),
                const SizedBox(height: 32),

                // HuggingFace API Key (Optional)
                Row(
                  children: [
                    Text(
                      'HuggingFace API Key',
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
                  'For AI-powered hints (free at huggingface.co/settings/tokens)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _huggingfaceController,
                  decoration: InputDecoration(
                    hintText: 'Enter HuggingFace API key (optional)',
                    contentPadding: const EdgeInsets.all(20),
                    suffixIcon: _hfValid == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(
                              _hfValid! ? Icons.check_circle : Icons.error,
                              color: _hfValid!
                                  ? const Color(0xFF4ADEAA)
                                  : const Color(0xFFFF6B7A),
                              size: 24,
                            ),
                          ),
                  ),
                  obscureText: true,
                  onChanged: (value) {
                    setState(() => _hfValid = null);
                  },
                  onSubmitted: (_) => _saveApiKeys(),
                ),
                const SizedBox(height: 12),
                if (_huggingfaceController.text.isNotEmpty && _hfValid == null)
                  OutlinedButton(
                    onPressed: _validateHFKey,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Validate HuggingFace Key'),
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
                          'Get FREE HuggingFace API key →',
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
