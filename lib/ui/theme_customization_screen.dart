import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/theme_settings.dart';
import '../providers/app_providers.dart';

// Preset theme palettes with improved colors
class ThemePalette {
  final String name;
  final String description;
  final Color primary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color success;
  final Color warning;
  final Color error;

  const ThemePalette({
    required this.name,
    required this.description,
    required this.primary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.success,
    required this.warning,
    required this.error,
  });
}

// Preset palettes for dark mode - Enhanced colors
final darkPalettes = [
  const ThemePalette(
    name: 'Cherry Blossom',
    description: 'Soft pink petals',
    primary: Color(0xFFF472B6),
    accent: Color(0xFFEC4899),
    background: Color(0xFF120A0F),
    surface: Color(0xFF1F141C),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFFDA4AF),
  ),
  const ThemePalette(
    name: 'Midnight Purple',
    description: 'Deep violet dreams',
    primary: Color(0xFF8B7CFF),
    accent: Color(0xFFB794F6),
    background: Color(0xFF0B0B0F),
    surface: Color(0xFF1A1A24),
    success: Color(0xFF3DDBA4),
    warning: Color(0xFFFFB86C),
    error: Color(0xFFFF6B7A),
  ),
  const ThemePalette(
    name: 'Ocean Deep',
    description: 'Tranquil waters',
    primary: Color(0xFF4FACFE),
    accent: Color(0xFF00F2FE),
    background: Color(0xFF08121C),
    surface: Color(0xFF0F1D2E),
    success: Color(0xFF2DD4BF),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
  ),
  const ThemePalette(
    name: 'Emerald Forest',
    description: 'Nature\'s embrace',
    primary: Color(0xFF34D399),
    accent: Color(0xFF6EE7B7),
    background: Color(0xFF0A0F0D),
    surface: Color(0xFF152420),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFCD34D),
    error: Color(0xFFFB7185),
  ),
  const ThemePalette(
    name: 'Sunset Blaze',
    description: 'Golden hour glow',
    primary: Color(0xFFFB923C),
    accent: Color(0xFFFF6B35),
    background: Color(0xFF120D08),
    surface: Color(0xFF1F1810),
    success: Color(0xFF22C55E),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFEF4444),
  ),
  const ThemePalette(
    name: 'Cosmic Void',
    description: 'Pure darkness',
    primary: Color(0xFF818CF8),
    accent: Color(0xFFA78BFA),
    background: Color(0xFF000000),
    surface: Color(0xFF0F0F14),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFDC2626),
  ),
  const ThemePalette(
    name: 'Neon Dreams',
    description: 'Cyberpunk vibes',
    primary: Color(0xFF00F5FF),
    accent: Color(0xFFFF2E97),
    background: Color(0xFF0A0A14),
    surface: Color(0xFF14141F),
    success: Color(0xFF39FF14),
    warning: Color(0xFFFFD700),
    error: Color(0xFFFF3864),
  ),
  const ThemePalette(
    name: 'Aurora Borealis',
    description: 'Northern lights',
    primary: Color(0xFF7FFFD4),
    accent: Color(0xFF9D84FF),
    background: Color(0xFF0C0E14),
    surface: Color(0xFF171B26),
    success: Color(0xFF5EEAD4),
    warning: Color(0xFFFFDA77),
    error: Color(0xFFFF8FAB),
  ),
];

// Preset palettes for light mode - Enhanced colors
final lightPalettes = [
  const ThemePalette(
    name: 'Cherry Blossom',
    description: 'Soft pink petals',
    primary: Color(0xFFEC4899),
    accent: Color(0xFFF472B6),
    background: Color(0xFFFFF1F2),
    surface: Color(0xFFFFFFFF),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFFDA4AF),
  ),
  const ThemePalette(
    name: 'Nordic Sky',
    description: 'Clean and modern',
    primary: Color(0xFF5B7FE8),
    accent: Color(0xFF7C6CF6),
    background: Color(0xFFF6F7FB),
    surface: Color(0xFFFFFFFF),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
  ),
  const ThemePalette(
    name: 'Azure Sky',
    description: 'Bright and clear',
    primary: Color(0xFF3B82F6),
    accent: Color(0xFF06B6D4),
    background: Color(0xFFEFF6FF),
    surface: Color(0xFFFFFFFF),
    success: Color(0xFF059669),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFDC2626),
  ),
  const ThemePalette(
    name: 'Mint Breeze',
    description: 'Fresh and cool',
    primary: Color(0xFF059669),
    accent: Color(0xFF14B8A6),
    background: Color(0xFFF0FDF9),
    surface: Color(0xFFFFFFFF),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
  ),
  const ThemePalette(
    name: 'Honey Gold',
    description: 'Warm and cozy',
    primary: Color(0xFFF59E0B),
    accent: Color(0xFFFB923C),
    background: Color(0xFFFFFBEB),
    surface: Color(0xFFFFFFFF),
    success: Color(0xFF10B981),
    warning: Color(0xFFEAB308),
    error: Color(0xFFDC2626),
  ),
  const ThemePalette(
    name: 'Lavender Mist',
    description: 'Soft and dreamy',
    primary: Color(0xFF8B5CF6),
    accent: Color(0xFFA78BFA),
    background: Color(0xFFFAF5FF),
    surface: Color(0xFFFFFFFF),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFE11D48),
  ),
  const ThemePalette(
    name: 'Monochrome',
    description: 'Timeless elegance',
    primary: Color(0xFF1E293B),
    accent: Color(0xFF475569),
    background: Color(0xFFFCFCFC),
    surface: Color(0xFFFFFFFF),
    success: Color(0xFF059669),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFDC2626),
  ),
  const ThemePalette(
    name: 'Coral Reef',
    description: 'Vibrant and lively',
    primary: Color(0xFFFF6B6B),
    accent: Color(0xFFFF8E53),
    background: Color(0xFFFFF5F5),
    surface: Color(0xFFFFFFFF),
    success: Color(0xFF20C997),
    warning: Color(0xFFFFC107),
    error: Color(0xFFE74C3C),
  ),
  const ThemePalette(
    name: 'Peachy Keen',
    description: 'Soft and playful',
    primary: Color(0xFFFF9A8B),
    accent: Color(0xFFFECFEF),
    background: Color(0xFFFFF8F4),
    surface: Color(0xFFFFFFFF),
    success: Color(0xFF48BB78),
    warning: Color(0xFFED8936),
    error: Color(0xFFF56565),
  ),
];

class ThemeCustomizationScreen extends ConsumerStatefulWidget {
  const ThemeCustomizationScreen({super.key});

  @override
  ConsumerState<ThemeCustomizationScreen> createState() =>
      _ThemeCustomizationScreenState();
}

class _ThemeCustomizationScreenState
    extends ConsumerState<ThemeCustomizationScreen> {
  late bool _isDarkMode;
  late Color _primaryColor;
  late Color _accentColor;
  late Color _backgroundColor;
  late Color _surfaceColor;
  late Color _successColor;
  late Color _warningColor;
  late Color _errorColor;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
  }

  Future<void> _loadCurrentTheme() async {
    final settings = ThemeSettings();
    final themeMode = await settings.getThemeMode();
    _isDarkMode = themeMode == ThemeMode.dark;

    final colors = await settings.loadAllColors(_isDarkMode);

    setState(() {
      _primaryColor = colors['primary']!;
      _accentColor = colors['accent']!;
      _backgroundColor = colors['background']!;
      _surfaceColor = colors['surface']!;
      _successColor = colors['success']!;
      _warningColor = colors['warning']!;
      _errorColor = colors['error']!;
      _isLoading = false;
    });
  }

  Future<void> _saveTheme() async {
    final settings = ThemeSettings();

    // Save theme mode
    await settings.saveThemeMode(
      _isDarkMode ? ThemeMode.dark : ThemeMode.light,
    );

    // Save colors
    await settings.saveAllColors(
      isDark: _isDarkMode,
      primary: _primaryColor,
      accent: _accentColor,
      background: _backgroundColor,
      surface: _surfaceColor,
      success: _successColor,
      warning: _warningColor,
      error: _errorColor,
    );

    // Invalidate providers to reload theme
    ref.invalidate(themeModeProvider);
    if (_isDarkMode) {
      ref.invalidate(darkThemeColorsProvider);
    } else {
      ref.invalidate(lightThemeColorsProvider);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Theme updated! Restart app to see all changes.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Theme?'),
        content: const Text(
          'This will reset all colors to their default values.',
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
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        if (_isDarkMode) {
          _primaryColor = ThemeSettings.defaultDarkPrimary;
          _accentColor = ThemeSettings.defaultDarkAccent;
          _backgroundColor = ThemeSettings.defaultDarkBackground;
          _surfaceColor = ThemeSettings.defaultDarkSurface;
          _successColor = ThemeSettings.defaultDarkSuccess;
          _warningColor = ThemeSettings.defaultDarkWarning;
          _errorColor = ThemeSettings.defaultDarkError;
        } else {
          _primaryColor = ThemeSettings.defaultLightPrimary;
          _accentColor = ThemeSettings.defaultLightAccent;
          _backgroundColor = ThemeSettings.defaultLightBackground;
          _surfaceColor = ThemeSettings.defaultLightSurface;
          _successColor = ThemeSettings.defaultLightSuccess;
          _warningColor = ThemeSettings.defaultLightWarning;
          _errorColor = ThemeSettings.defaultLightError;
        }
      });
    }
  }

  void _applyPalette(ThemePalette palette) {
    setState(() {
      _primaryColor = palette.primary;
      _accentColor = palette.accent;
      _backgroundColor = palette.background;
      _surfaceColor = palette.surface;
      _successColor = palette.success;
      _warningColor = palette.warning;
      _errorColor = palette.error;
    });
  }

  Future<void> _pickColor(
    String label,
    Color currentColor,
    Function(Color) onColorChanged,
  ) async {
    Color pickerColor = currentColor;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pick $label Color'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorPicker(
                pickerColor: pickerColor,
                onColorChanged: (color) => pickerColor = color,
                pickerAreaHeightPercent: 0.8,
                enableAlpha: false,
                displayThumbColor: true,
                labelTypes: const [],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _HexColorInput(
                initialColor: pickerColor,
                onColorChanged: (color) {
                  if (color != null) {
                    pickerColor = color;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => onColorChanged(pickerColor));
              Navigator.pop(context);
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  void _showPalettes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: _isDarkMode
                ? const Color(0xFF0F0F14)
                : const Color(0xFFF8F9FB),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _isDarkMode
                      ? Colors.white.withOpacity(0.3)
                      : Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose Your Vibe',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: _isDarkMode ? Colors.white : Colors.black,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap a palette to apply',
                          style: TextStyle(
                            fontSize: 14,
                            color: _isDarkMode
                                ? Colors.white.withOpacity(0.6)
                                : Colors.black.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: _isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _isDarkMode
                      ? darkPalettes.length
                      : lightPalettes.length,
                  itemBuilder: (context, index) {
                    final palette = _isDarkMode
                        ? darkPalettes[index]
                        : lightPalettes[index];
                    return _ModernPaletteCard(
                      palette: palette,
                      isDark: _isDarkMode,
                      onTap: () {
                        _applyPalette(palette);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Customization'),
        actions: [
          IconButton(
            onPressed: _resetToDefaults,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to defaults',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _saveTheme,
              icon: const Icon(Icons.check),
              tooltip: 'Save theme',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme mode selector
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
                  'Theme Mode',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode),
                    ),
                  ],
                  selected: {_isDarkMode},
                  onSelectionChanged: (Set<bool> newSelection) async {
                    final newMode = newSelection.first;
                    setState(() => _isDarkMode = newMode);
                    // Reload colors for the new mode
                    final settings = ThemeSettings();
                    final colors = await settings.loadAllColors(_isDarkMode);
                    setState(() {
                      _primaryColor = colors['primary']!;
                      _accentColor = colors['accent']!;
                      _backgroundColor = colors['background']!;
                      _surfaceColor = colors['surface']!;
                      _successColor = colors['success']!;
                      _warningColor = colors['warning']!;
                      _errorColor = colors['error']!;
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Palette picker button - Enhanced
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withOpacity(0.15),
                  _accentColor.withOpacity(0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _primaryColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showPalettes,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.palette,
                          color: _primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Browse Palettes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Quick preset color combinations',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 18,
                        color: _primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Colors',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          // Primary color
          _ColorTile(
            label: 'Primary Color',
            description: 'Main interactive elements',
            color: _primaryColor,
            onTap: () => _pickColor(
              'Primary',
              _primaryColor,
              (color) => _primaryColor = color,
            ),
          ),
          const SizedBox(height: 8),

          // Accent color
          _ColorTile(
            label: 'Accent Color',
            description: 'Secondary highlights',
            color: _accentColor,
            onTap: () => _pickColor(
              'Accent',
              _accentColor,
              (color) => _accentColor = color,
            ),
          ),
          const SizedBox(height: 8),

          // Background color
          _ColorTile(
            label: 'Background Color',
            description: 'Main background',
            color: _backgroundColor,
            onTap: () => _pickColor(
              'Background',
              _backgroundColor,
              (color) => _backgroundColor = color,
            ),
          ),
          const SizedBox(height: 8),

          // Surface color
          _ColorTile(
            label: 'Surface Color',
            description: 'Cards and containers',
            color: _surfaceColor,
            onTap: () => _pickColor(
              'Surface',
              _surfaceColor,
              (color) => _surfaceColor = color,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Status Colors',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          // Success color
          _ColorTile(
            label: 'Success Color',
            description: 'Positive states',
            color: _successColor,
            onTap: () => _pickColor(
              'Success',
              _successColor,
              (color) => _successColor = color,
            ),
          ),
          const SizedBox(height: 8),

          // Warning color
          _ColorTile(
            label: 'Warning Color',
            description: 'Caution states',
            color: _warningColor,
            onTap: () => _pickColor(
              'Warning',
              _warningColor,
              (color) => _warningColor = color,
            ),
          ),
          const SizedBox(height: 8),

          // Error color
          _ColorTile(
            label: 'Error Color',
            description: 'Error states',
            color: _errorColor,
            onTap: () => _pickColor(
              'Error',
              _errorColor,
              (color) => _errorColor = color,
            ),
          ),

          const SizedBox(height: 32),

          // Preview section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _isDarkMode
                        ? const Color(0xFFF8F8FB)
                        : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: _isDarkMode
                                    ? Colors.black
                                    : Colors.white,
                              ),
                              child: const Text('Primary'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _isDarkMode
                                    ? const Color(0xFFF8F8FB)
                                    : const Color(0xFF1A1A1A),
                              ),
                              child: const Text('Outlined'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatusChip('Success', _successColor),
                          _StatusChip('Warning', _warningColor),
                          _StatusChip('Error', _errorColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ModernPaletteCard extends StatelessWidget {
  final ThemePalette palette;
  final bool isDark;
  final VoidCallback onTap;

  const _ModernPaletteCard({
    required this.palette,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.background, palette.surface],
          ),
          border: Border.all(
            color: palette.primary.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: palette.primary.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        palette.primary.withOpacity(0.05),
                        palette.accent.withOpacity(0.05),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      palette.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      palette.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black.withOpacity(0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const Spacer(),

                    // Color dots in modern grid
                    Column(
                      children: [
                        Row(
                          children: [
                            _ModernColorDot(palette.primary, size: 36),
                            const SizedBox(width: 8),
                            _ModernColorDot(palette.accent, size: 36),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _ModernColorDot(palette.success, size: 24),
                            const SizedBox(width: 6),
                            _ModernColorDot(palette.warning, size: 24),
                            const SizedBox(width: 6),
                            _ModernColorDot(palette.error, size: 24),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Tap indicator
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: palette.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: palette.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernColorDot extends StatelessWidget {
  final Color color;
  final double size;

  const _ModernColorDot(this.color, {this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
      ),
    );
  }
}

class _HexColorInput extends StatefulWidget {
  final Color initialColor;
  final Function(Color?) onColorChanged;

  const _HexColorInput({
    required this.initialColor,
    required this.onColorChanged,
  });

  @override
  State<_HexColorInput> createState() => _HexColorInputState();
}

class _HexColorInputState extends State<_HexColorInput> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialColor.value
          .toRadixString(16)
          .substring(2)
          .toUpperCase(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color? _parseHex(String hex) {
    hex = hex.replaceAll('#', '').trim().toUpperCase();

    // Support both RGB (6 chars) and ARGB (8 chars)
    if (hex.length == 6) {
      hex = 'FF$hex';
    }

    if (hex.length != 8) {
      return null;
    }

    try {
      final value = int.parse(hex, radix: 16);
      return Color(value);
    } catch (e) {
      return null;
    }
  }

  void _validateAndUpdate(String value) {
    final color = _parseHex(value);

    setState(() {
      if (color != null) {
        _errorText = null;
        widget.onColorChanged(color);
      } else if (value.isNotEmpty) {
        _errorText = 'Invalid hex color';
        widget.onColorChanged(null);
      } else {
        _errorText = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Or enter hex code',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            prefixText: '#',
            hintText: 'RRGGBB',
            errorText: _errorText,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
            LengthLimitingTextInputFormatter(8),
            UpperCaseTextFormatter(),
          ],
          onChanged: _validateAndUpdate,
        ),
      ],
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class _ColorTile extends StatelessWidget {
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ColorTile({
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_outlined,
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

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
