import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'translate_screen.dart';
import 'recall_screen.dart';
import 'settings_screen.dart';
import '../providers/app_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh due word count when app comes to foreground
      ref.invalidate(dueWordCountProvider);
      if (_currentIndex == 1) {
        ref.invalidate(dueWordsProvider);
      }
    }
  }

  void _onPageChanged(int index) {
    final previousIndex = _currentIndex;
    setState(() => _currentIndex = index);

    // When switching TO the Recall tab, always refresh due words
    if (index == 1 && previousIndex != 1) {
      ref.invalidate(dueWordsProvider);
      ref.invalidate(dueWordCountProvider);
    }
  }

  void _onNavTap(int index) {
    // Use jumpToPage for direct navigation to avoid scroll-through effect
    // Only animate if moving to adjacent page
    final distance = (index - _currentIndex).abs();

    if (distance <= 1) {
      // Adjacent pages: smooth animation is fine
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Non-adjacent pages: jump directly to avoid scroll-through
      _pageController.jumpToPage(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueCountAsync = ref.watch(dueWordCountProvider);

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: const [
          TranslateScreen(keepAlive: true),
          RecallScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.surface,
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onNavTap,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.translate),
              selectedIcon: Icon(Icons.translate),
              label: 'Translate',
            ),
            NavigationDestination(
              icon: dueCountAsync.when(
                data: (count) => count > 0
                    ? Badge(
                        label: Text('$count'),
                        child: const Icon(Icons.school_outlined),
                      )
                    : const Icon(Icons.school_outlined),
                loading: () => const Icon(Icons.school_outlined),
                error: (_, __) => const Icon(Icons.school_outlined),
              ),
              selectedIcon: dueCountAsync.when(
                data: (count) => count > 0
                    ? Badge(
                        label: Text('$count'),
                        child: const Icon(Icons.school),
                      )
                    : const Icon(Icons.school),
                loading: () => const Icon(Icons.school),
                error: (_, __) => const Icon(Icons.school),
              ),
              label: 'Recall',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
