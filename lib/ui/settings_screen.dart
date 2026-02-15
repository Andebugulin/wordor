import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/app_providers.dart';
import '../services/notification_service.dart';
import '../services/ai_hint_service.dart';
import 'word_library_screen.dart';
import 'theme_customization_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = false;
  List<ReminderTime> _reminders = [];
  AIProvider _selectedAIProvider = AIProvider.huggingface;
  String? _selectedHFModel;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Load notification and AI provider settings from storage
  Future<void> _loadSettings() async {
    final enabled = await NotificationService.areNotificationsEnabled();
    final reminders = await NotificationService.getReminders();
    final prefs = await SharedPreferences.getInstance();
    final providerName = prefs.getString('ai_provider') ?? 'huggingface';

    final storage = ref.read(apiKeyStorageProvider);
    final savedModel = await storage.getHuggingFaceModel();

    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
        _reminders = reminders;
        _selectedAIProvider = providerName == 'gemini'
            ? AIProvider.gemini
            : AIProvider.huggingface;
        _selectedHFModel = savedModel;
      });
    }
  }

  /// Save the selected AI provider to preferences
  Future<void> _saveAIProvider(AIProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'ai_provider',
      provider == AIProvider.gemini ? 'gemini' : 'huggingface',
    );

    ref.invalidate(aiProviderPreferenceProvider);
    ref.invalidate(aiHintServiceProvider);

    if (mounted) {
      setState(() {
        _selectedAIProvider = provider;
      });
    }
  }

  /// Save the selected HuggingFace model to storage
  Future<void> _saveHFModel(String modelId) async {
    final storage = ref.read(apiKeyStorageProvider);
    await storage.saveHuggingFaceModel(modelId);

    if (mounted) {
      setState(() => _selectedHFModel = modelId);
    }

    ref.invalidate(huggingfaceModelProvider);
    ref.invalidate(aiHintServiceProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Model changed to ${AIHintService.recommendedModels.firstWhere((m) => m.id == modelId).name}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Check if the currently selected AI provider has an API key configured
  bool _hasCurrentAIKey() {
    if (_selectedAIProvider == AIProvider.huggingface) {
      final hfKeyAsync = ref.read(huggingfaceApiKeyProvider);
      return hfKeyAsync.value != null && hfKeyAsync.value!.isNotEmpty;
    } else {
      final geminiKeyAsync = ref.read(geminiApiKeyProvider);
      return geminiKeyAsync.value != null && geminiKeyAsync.value!.isNotEmpty;
    }
  }

  /// Launch a URL in the system browser
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not launch URL')));
      }
    }
  }

  String _formatReminder(ReminderTime r) {
    final tod = TimeOfDay(hour: r.hour, minute: r.minute);
    return tod.format(context);
  }

  @override
  Widget build(BuildContext context) {
    final deeplKeyAsync = ref.watch(apiKeyProvider);
    final hasDeepLKey = deeplKeyAsync.value != null;

    final geminiKeyAsync = ref.watch(geminiApiKeyProvider);
    final hasGeminiKey =
        geminiKeyAsync.value != null && geminiKeyAsync.value!.isNotEmpty;

    final hasAIKey = _hasCurrentAIKey();
    final hfKeyAsync = ref.watch(huggingfaceApiKeyProvider);
    final hasHFKey = hfKeyAsync.value != null && hfKeyAsync.value!.isNotEmpty;

    final githubStarsAsync = ref.watch(githubStarsProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: Row(
          children: [
            const Text('Settings'),
            const SizedBox(width: 12),
            _KeyStatusIndicator(
              icon: Icons.key,
              isActive: hasDeepLKey,
              tooltip: hasDeepLKey
                  ? 'DeepL key configured'
                  : 'DeepL key missing',
            ),
            const SizedBox(width: 8),
            _KeyStatusIndicator(
              icon: Icons.auto_awesome,
              isActive: hasAIKey,
              tooltip: hasAIKey ? 'AI key configured' : 'AI key missing',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 16),
                  _SettingsTile(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    subtitle: 'Customize colors and appearance',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ThemeCustomizationScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.library_books_outlined,
                    title: 'Saved Words',
                    subtitle: 'View, manage, import & export',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WordLibraryScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTileWithStatus(
                    icon: Icons.key_outlined,
                    title: 'DeepL API Key',
                    subtitle: hasDeepLKey
                        ? 'Configured'
                        : 'Required for translation',
                    hasKey: hasDeepLKey,
                    onTap: () => _showDeepLApiKeyDialog(context, ref),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'AI Hints (Optional)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Provider',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        RadioListTile<AIProvider>(
                          title: const Text('HuggingFace (Recommended)'),
                          subtitle: const Text(
                            'Free, fast, customizable models',
                          ),
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
                  _SettingsTileWithStatus(
                    icon: Icons.auto_awesome_outlined,
                    title: 'HuggingFace API Key',
                    subtitle: _selectedAIProvider == AIProvider.huggingface
                        ? (hasHFKey ? 'Configured' : 'Get free key here')
                        : 'Not active',
                    hasKey: hasHFKey,
                    isActive: _selectedAIProvider == AIProvider.huggingface,
                    onTap: () => _showHuggingFaceApiKeyDialog(context, ref),
                    subtitleUrl:
                        !hasHFKey &&
                            _selectedAIProvider == AIProvider.huggingface
                        ? 'https://huggingface.co/settings/tokens'
                        : null,
                  ),
                  if (_selectedAIProvider == AIProvider.huggingface) ...[
                    const SizedBox(height: 8),
                    _SettingsTile(
                      icon: Icons.settings_suggest_outlined,
                      title: 'HuggingFace Model',
                      subtitle: _getModelName(_selectedHFModel),
                      onTap: () => _showModelSelector(context),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _SettingsTileWithStatus(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Gemini API Key',
                    subtitle: _selectedAIProvider == AIProvider.gemini
                        ? (hasGeminiKey ? 'Configured' : 'Get free key here')
                        : 'Not active',
                    hasKey: hasGeminiKey,
                    isActive: _selectedAIProvider == AIProvider.gemini,
                    onTap: () => _showGeminiApiKeyDialog(context, ref),
                    subtitleUrl:
                        !hasGeminiKey &&
                            _selectedAIProvider == AIProvider.gemini
                        ? 'https://aistudio.google.com/api-keys'
                        : null,
                  ),

                  // ── Notifications ─────────────────────────────────
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Notifications',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Master switch
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.notifications_outlined,
                            color: colors.primary,
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
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _notificationsEnabled && _reminders.isNotEmpty
                                    ? '${_reminders.length} ${_reminders.length == 1 ? "reminder" : "reminders"} set'
                                    : 'Get reminded to review words',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _notificationsEnabled,
                          onChanged: (value) async {
                            if (value) {
                              if (_reminders.isEmpty) {
                                // No reminders yet — show picker to add one
                                await _addNewReminder();
                              } else {
                                // Re-enable existing reminders
                                await NotificationService.enableNotifications();
                                setState(() => _notificationsEnabled = true);
                              }
                            } else {
                              await NotificationService.disableNotifications();
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

                  // List of configured reminders
                  if (_notificationsEnabled && _reminders.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < _reminders.length; i++)
                            ListTile(
                              leading: Icon(
                                Icons.schedule_outlined,
                                color: colors.primary,
                              ),
                              title: Text(
                                _formatReminder(_reminders[i]),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () => _editReminder(i),
                                    tooltip: 'Change time',
                                  ),
                                  if (_reminders.length > 1)
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: colors.error,
                                      ),
                                      onPressed: () => _removeReminder(i),
                                      tooltip: 'Remove',
                                    ),
                                ],
                              ),
                            ),
                          if (_reminders.length < 5)
                            ListTile(
                              leading: Icon(
                                Icons.add_alarm_outlined,
                                color: colors.primary.withOpacity(0.6),
                              ),
                              title: Text(
                                'Add another reminder',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onTap: _addNewReminder,
                            ),
                        ],
                      ),
                    ),
                  ],

                  // ── Danger Zone ───────────────────────────────────
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Danger Zone',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.error,
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wordor', style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Version 1.1.0',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Connect',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        githubStarsAsync.when(
                          data: (stars) => _GitHubLinkTile(
                            stars: stars,
                            onTap: () => _launchURL(
                              'https://github.com/andebugulin/wordor',
                            ),
                          ),
                          loading: () => _GitHubLinkTile(
                            stars: null,
                            onTap: () => _launchURL(
                              'https://github.com/andebugulin/wordor',
                            ),
                          ),
                          error: (_, __) => _GitHubLinkTile(
                            stars: null,
                            onTap: () => _launchURL(
                              'https://github.com/andebugulin/wordor',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SocialLinkTile(
                          icon: Icons.work_outline,
                          title: 'LinkedIn',
                          subtitle: 'Connect with me',
                          onTap: () => _launchURL(
                            'https://www.linkedin.com/in/andrei-gulin',
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

  // ── Notification helpers ────────────────────────────────────────

  Future<void> _addNewReminder() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
    );

    if (time != null && mounted) {
      try {
        await NotificationService.addReminder(
          ReminderTime(hour: time.hour, minute: time.minute),
        );
        await _loadSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reminder set for ${time.format(context)}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to set reminder: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _editReminder(int index) async {
    final current = _reminders[index];
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );

    if (time != null && mounted) {
      try {
        await NotificationService.updateReminder(
          current,
          ReminderTime(hour: time.hour, minute: time.minute),
        );
        await _loadSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reminder updated to ${time.format(context)}'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update reminder: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeReminder(int index) async {
    final reminder = _reminders[index];
    await NotificationService.removeReminder(reminder);
    await _loadSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder at ${_formatReminder(reminder)} removed'),
        ),
      );
    }
  }

  // ── Model picker ──────────────────────────────────────────────────

  String _getModelName(String? modelId) {
    if (modelId == null) {
      return 'Default (Moonshotai Kimi-K2)';
    }

    final model = AIHintService.recommendedModels.firstWhere(
      (m) => m.id == modelId,
      orElse: () => const HFModel(
        name: 'Custom Model',
        id: '__custom__',
        description: '',
      ),
    );

    if (model.id == '__custom__') {
      if (modelId.length > 30) {
        return '${modelId.substring(0, 27)}...';
      }
      return modelId;
    }

    return model.name;
  }

  Future<void> _showModelSelector(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Select HuggingFace Model',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ...AIHintService.recommendedModels.map((model) {
              final isSelected =
                  _selectedHFModel == model.id ||
                  (_selectedHFModel == null &&
                      model.id == AIHintService.defaultHFModel);

              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Row(
                  children: [
                    Text(model.name),
                    if (model.recommended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'RECOMMENDED',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(model.description),
                onTap: () async {
                  if (model.id == '__custom__') {
                    Navigator.pop(context);
                    await _showCustomModelDialog(context);
                  } else {
                    Navigator.pop(context, model.id);
                  }
                },
                selected: isSelected,
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (result != null && result != '__custom__') {
      await _saveHFModel(result);
    }
  }

  Future<void> _showCustomModelDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom HuggingFace Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the model string from HuggingFace Router API:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText:
                    'e.g., mistralai/Mistral-7B-Instruct-v0.2:featherless-ai',
                helperText: 'Format: provider/model:endpoint',
              ),
              maxLines: 2,
            ),
          ],
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
      await _saveHFModel(result);
    }
  }

  // ── API key dialogs ───────────────────────────────────────────────

  Future<void> _showDeepLApiKeyDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    final storage = ref.read(apiKeyStorageProvider);
    final existingKey = await storage.getApiKey();

    if (existingKey != null && existingKey.isNotEmpty) {
      controller.text = '\u2022' * 20;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DeepL API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (existingKey != null && existingKey.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'API key is configured',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Paste your DeepL API key',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          if (existingKey != null)
            TextButton(
              onPressed: () async {
                await storage.deleteApiKey();
                ref.invalidate(apiKeyProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('DeepL API key removed')),
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

    if (result != null && result.isNotEmpty && result != '\u2022' * 20) {
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
    final storage = ref.read(apiKeyStorageProvider);
    final existingKey = await storage.getHuggingFaceApiKey();

    if (existingKey != null && existingKey.isNotEmpty) {
      controller.text = '\u2022' * 20;
    }

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
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (existingKey != null && existingKey.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'API key is configured',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ),
            GestureDetector(
              onTap: () => _launchURL('https://huggingface.co/settings/tokens'),
              child: Text(
                'Get free key here',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
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
              await storage.deleteHuggingFaceApiKey();
              ref.invalidate(huggingfaceApiKeyProvider);
              ref.invalidate(currentAIProviderHasKeyProvider);
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

    if (result != null && result.isNotEmpty && result != '\u2022' * 20) {
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
      ref.invalidate(currentAIProviderHasKeyProvider);

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
    final controller = TextEditingController();
    final storage = ref.read(apiKeyStorageProvider);
    final existingKey = await storage.getGeminiApiKey();

    if (existingKey != null && existingKey.isNotEmpty) {
      controller.text = '\u2022' * 20;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gemini API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (existingKey != null && existingKey.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'API key is configured',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ),
            const Text('Free at ai.google.dev'),
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
              await storage.deleteGeminiApiKey();
              ref.invalidate(geminiApiKeyProvider);
              ref.invalidate(currentAIProviderHasKeyProvider);
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

    if (result != null && result.isNotEmpty && result != '\u2022' * 20) {
      final storage = ref.read(apiKeyStorageProvider);
      await storage.saveGeminiApiKey(result);
      ref.invalidate(geminiApiKeyProvider);
      ref.invalidate(currentAIProviderHasKeyProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gemini API key saved!')));
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

// ── Reusable widgets ────────────────────────────────────────────────

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

class _SettingsTileWithStatus extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool hasKey;
  final bool isActive;
  final String? subtitleUrl;

  const _SettingsTileWithStatus({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.hasKey,
    this.isActive = true,
    this.subtitleUrl,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Match translate_screen indicator colors for consistency
    const green = Color(0xFF4ADEAA);
    const red = Color(0xFFFF6B7A);
    final statusColor = hasKey && isActive ? green : red;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: colors.primary, size: 24),
                  ),
                  if (isActive)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 2),
                        ),
                      ),
                    ),
                ],
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
                    subtitleUrl != null
                        ? GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse(subtitleUrl!);
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            },
                            child: Row(
                              children: [
                                Text(
                                  subtitle,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.open_in_new,
                                  size: 14,
                                  color: colors.primary,
                                ),
                              ],
                            ),
                          )
                        : Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: hasKey && isActive
                                      ? statusColor
                                      : Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                ),
                          ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colors.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GitHubLinkTile extends StatelessWidget {
  final int? stars;
  final VoidCallback onTap;

  const _GitHubLinkTile({required this.stars, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                child: FaIcon(
                  FontAwesomeIcons.github,
                  size: 20,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GitHub',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Source code',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (stars != null && stars! > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colors.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 14, color: colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '$stars',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.open_in_new,
                size: 16,
                color: colors.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialLinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SocialLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 16,
                color: colors.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyStatusIndicator extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final String tooltip;

  // Match translate_screen indicator colors for consistency
  static const _green = Color(0xFF4ADEAA);
  static const _red = Color(0xFFFF6B7A);

  const _KeyStatusIndicator({
    required this.icon,
    required this.isActive,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _green : _red;

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}
