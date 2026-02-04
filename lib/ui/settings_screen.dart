import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_providers.dart';
import '../services/notification_service.dart';
import '../services/ai_hint_service.dart';
import 'word_library_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = false;
  String _notificationTime = 'Not set';
  AIProvider _selectedAIProvider = AIProvider.huggingface;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await NotificationService.areNotificationsEnabled();
    final savedTime = await NotificationService.getSavedNotificationTime();
    final prefs = await SharedPreferences.getInstance();
    final providerName = prefs.getString('ai_provider') ?? 'huggingface';

    setState(() {
      _notificationsEnabled = enabled;
      _selectedAIProvider = providerName == 'gemini'
          ? AIProvider.gemini
          : AIProvider.huggingface;
      if (savedTime != null) {
        final hour = savedTime['hour']!;
        final minute = savedTime['minute']!;
        _notificationTime = TimeOfDay(
          hour: hour,
          minute: minute,
        ).format(context);
      }
    });
  }

  Future<void> _saveAIProvider(AIProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'ai_provider',
      provider == AIProvider.gemini ? 'gemini' : 'huggingface',
    );
    setState(() => _selectedAIProvider = provider);
    ref.invalidate(aiProviderPreferenceProvider);
    ref.invalidate(aiHintServiceProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Settings',
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _SettingsTile(
                    icon: Icons.library_books_outlined,
                    title: 'Saved Words',
                    subtitle: 'View and manage your words',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WordLibraryScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // DeepL API Key
                  _SettingsTile(
                    icon: Icons.key_outlined,
                    title: 'DeepL API Key',
                    subtitle: 'Required for translation',
                    onTap: () => _showDeepLApiKeyDialog(context, ref),
                  ),
                  const SizedBox(height: 16),

                  // AI Provider Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'AI Hints (Optional)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // AI Provider selector
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Provider',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        RadioListTile<AIProvider>(
                          title: const Text('HuggingFace (Recommended)'),
                          subtitle: const Text('Free, fast, reliable'),
                          value: AIProvider.huggingface,
                          groupValue: _selectedAIProvider,
                          onChanged: (value) =>
                              value != null ? _saveAIProvider(value) : null,
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<AIProvider>(
                          title: const Text('Gemini'),
                          subtitle: const Text('Google AI'),
                          value: AIProvider.gemini,
                          groupValue: _selectedAIProvider,
                          onChanged: (value) =>
                              value != null ? _saveAIProvider(value) : null,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // HuggingFace API Key
                  _SettingsTile(
                    icon: Icons.auto_awesome_outlined,
                    title: 'HuggingFace API Key',
                    subtitle: _selectedAIProvider == AIProvider.huggingface
                        ? 'Get free key at huggingface.co'
                        : 'Not active',
                    onTap: () => _showHuggingFaceApiKeyDialog(context, ref),
                  ),
                  const SizedBox(height: 8),

                  // Gemini API Key
                  _SettingsTile(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Gemini API Key',
                    subtitle: _selectedAIProvider == AIProvider.gemini
                        ? 'Get free key at ai.google.dev'
                        : 'Not active',
                    onTap: () => _showGeminiApiKeyDialog(context, ref),
                  ),

                  const SizedBox(height: 32),

                  // Notifications section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.notifications_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Reminders',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _notificationsEnabled
                                    ? 'Enabled at $_notificationTime'
                                    : 'Get reminded to review words',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _notificationsEnabled,
                          onChanged: (value) async {
                            if (value) {
                              await _showTimePickerDialog(context);
                            } else {
                              await NotificationService.cancelDailyNotification();
                              setState(() => _notificationsEnabled = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Daily reminders disabled'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  if (_notificationsEnabled) ...[
                    const SizedBox(height: 8),
                    _SettingsTile(
                      icon: Icons.schedule_outlined,
                      title: 'Change Reminder Time',
                      subtitle: 'Currently set to $_notificationTime',
                      onTap: () => _showTimePickerDialog(context),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Debug section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Debug & Testing',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.notifications_active,
                    title: 'Test Notification',
                    subtitle: 'Send a test notification now',
                    onTap: () => _sendTestNotification(context, ref),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.fast_forward,
                    title: 'Make All Words Due',
                    subtitle: 'Test recall immediately',
                    onTap: () => _makeAllWordsDue(context, ref),
                  ),

                  const SizedBox(height: 32),

                  // Danger zone
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Danger Zone',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.delete_outline,
                    title: 'Clear Data',
                    subtitle: 'Remove all saved words',
                    onTap: () => _showClearDataDialog(context, ref),
                    isDestructive: true,
                  ),

                  const SizedBox(height: 32),

                  // App info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Word Recall',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version 1.1.0',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog methods (DeepL, HuggingFace, Gemini, etc.)
  Future<void> _showDeepLApiKeyDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DeepL API Key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Paste your DeepL API key',
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final storage = ref.read(apiKeyStorageProvider);
      await storage.saveApiKey(result);
      ref.invalidate(apiKeyProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('DeepL API key updated')));
      }
    }
  }

  Future<void> _showHuggingFaceApiKeyDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Text('HuggingFace API Key'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Recommended',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Free at huggingface.co/settings/tokens'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Paste HuggingFace API key',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final storage = ref.read(apiKeyStorageProvider);
              await storage.deleteHuggingFaceApiKey();
              ref.invalidate(huggingfaceApiKeyProvider);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('HuggingFace API key removed')),
                );
              }
            },
            child: const Text('Remove'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final storage = ref.read(apiKeyStorageProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Validating API key...'),
            duration: Duration(seconds: 10),
          ),
        );
      }

      final aiService = AIHintService(result, AIProvider.huggingface);
      final validation = await aiService.validateApiKey();

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }

      if (!validation['valid']) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('API Key Validation Failed'),
              content: Text(validation['message'] ?? 'Unknown error'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      await storage.saveHuggingFaceApiKey(result);
      ref.invalidate(huggingfaceApiKeyProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('HuggingFace API key saved!')),
        );
      }
    }
  }

  Future<void> _showGeminiApiKeyDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Similar implementation as HuggingFace dialog
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gemini API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Free at ai.google.dev'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Paste Gemini API key',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final storage = ref.read(apiKeyStorageProvider);
              await storage.deleteGeminiApiKey();
              ref.invalidate(geminiApiKeyProvider);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gemini API key removed')),
                );
              }
            },
            child: const Text('Remove'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final storage = ref.read(apiKeyStorageProvider);
      await storage.saveGeminiApiKey(result);
      ref.invalidate(geminiApiKeyProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gemini API key saved!')));
      }
    }
  }

  Future<void> _showTimePickerDialog(BuildContext context) async {
    final savedTime = await NotificationService.getSavedNotificationTime();
    final initialTime = savedTime != null
        ? TimeOfDay(hour: savedTime['hour']!, minute: savedTime['minute']!)
        : const TimeOfDay(hour: 20, minute: 0);

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time != null) {
      await NotificationService.scheduleDailyNotification(
        hour: time.hour,
        minute: time.minute,
      );
      await _loadSettings();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Daily reminder set for ${time.format(context)}'),
          ),
        );
      }
    }
  }

  Future<void> _sendTestNotification(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final db = ref.read(databaseProvider);
    final count = await db.getDueWordCount();
    await NotificationService.showImmediateNotification(count > 0 ? count : 1);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Test notification sent')));
    }
  }

  Future<void> _makeAllWordsDue(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make All Words Due?'),
        content: const Text(
          'This will make all saved words available for review immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Make Due'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.makeAllWordsDueNow();
      ref.invalidate(dueWordsProvider);
      ref.invalidate(dueWordCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All words are now due for review')),
        );
      }
    }
  }

  Future<void> _showClearDataDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all saved words and progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.delete(db.words).go();
      await db.delete(db.recalls).go();
      ref.invalidate(dueWordsProvider);
      ref.invalidate(dueWordCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('All data cleared')));
      }
    }
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
