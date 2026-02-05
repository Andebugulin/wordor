import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'translate_screen.dart';
import 'recall_screen.dart';
import 'settings_screen.dart';
import '../providers/app_providers.dart';
import '../services/notification_service.dart';

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
    _checkDueWordsOnLaunch();
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
      // Check for due words when app comes to foreground
      _checkDueWordsOnLaunch();
    }
  }

  Future<void> _checkDueWordsOnLaunch() async {
    // Wait a bit for the app to fully load
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final dueCountAsync = ref.read(dueWordCountProvider);

    dueCountAsync.when(
      data: (count) async {
        if (count > 0) {
          await NotificationService.checkAndNotifyDueWords(count);
        }
      },
      loading: () {},
      error: (_, __) {},
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _onNavTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
                        child: const Icon(Icons.notifications_outlined),
                      )
                    : const Icon(Icons.notifications_outlined),
                loading: () => const Icon(Icons.notifications_outlined),
                error: (_, __) => const Icon(Icons.notifications_outlined),
              ),
              selectedIcon: dueCountAsync.when(
                data: (count) => count > 0
                    ? Badge(
                        label: Text('$count'),
                        child: const Icon(Icons.notifications),
                      )
                    : const Icon(Icons.notifications),
                loading: () => const Icon(Icons.notifications),
                error: (_, __) => const Icon(Icons.notifications),
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
