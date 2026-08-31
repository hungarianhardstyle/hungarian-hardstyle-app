import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'events/events_screen.dart';
import 'community/community_screen.dart';
import 'home/home_screen.dart';
import 'more/more_screen.dart';
import 'news/news_screen.dart';
import 'releases/releases_screen.dart';
import '../widgets/radio_player_bar.dart';
import '../services/app_update_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  static const _tabCount = 6;
  int _currentIndex = 0;
  final _navigatorKeys = List.generate(
    _tabCount,
    (_) => GlobalKey<NavigatorState>(),
  );
  final _releasesKey = GlobalKey<ReleasesScreenState>();
  final _tabs = List<Widget?>.filled(_tabCount, null);
  bool _checkingUpdate = false;
  bool _updateDialogOpen = false;
  bool _exitDialogOpen = false;
  bool _backHandling = false;
  DateTime? _lastSystemBackAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForUpdate();
    }
  }

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate || _updateDialogOpen || !mounted) return;
    _checkingUpdate = true;
    try {
      final info = await AppUpdateService().check();
      if (info == null || !mounted || _updateDialogOpen) return;
      _updateDialogOpen = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Új verzió érhető el'),
          content: const Text(
            'Frissítsd az alkalmazást a legújabb javításokért.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Most nem'),
            ),
            FilledButton(
              onPressed: () async {
                await AppUpdateService().start(info);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Frissítés'),
            ),
          ],
        ),
      );
    } finally {
      _updateDialogOpen = false;
      _checkingUpdate = false;
    }
  }

  void _setCurrentIndex(int index) {
    if (index == 4) {
      final releasesState = _releasesKey.currentState;
      if (releasesState != null) unawaited(releasesState.refreshNow());
    }
    if (mounted) setState(() => _currentIndex = index);
  }

  void _openNewsTab() => _setCurrentIndex(1);

  Widget _tabNavigator(int index) {
    final navigator = Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (context) {
          switch (index) {
            case 0:
              return HomeScreen(onShowMoreNews: _openNewsTab);
            case 1:
              return const NewsScreen();
            case 2:
              return const EventsScreen();
            case 3:
              return const LiveFeedScreen();
            case 4:
              return ReleasesScreen(key: _releasesKey);
            default:
              return const MoreScreen();
          }
        },
      ),
    );
    // Back is handled once by the outer PopScope. Having a second PopScope
    // around every tab lets Flutter dispatch the same system event through
    // both the tab root and MainNavigation, which can empty a tab or bypass
    // the home exit confirmation.
    return navigator;
  }

  Widget _tabFor(int index) => _tabs[index] ??= _tabNavigator(index);

  Widget _contentStack() => IndexedStack(
    index: _currentIndex,
    children: List.generate(_tabCount, (index) {
      final tab = _tabs[index];
      if (tab == null) return const SizedBox.shrink();
      return tab;
    }),
  );

  Future<void> _confirmExit() async {
    if (_exitDialogOpen || !mounted) return;
    _exitDialogOpen = true;
    try {
      final exit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Kilépés'),
          content: const Text('Biztosan ki szeretnél lépni az alkalmazásból?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Mégse'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Kilépés'),
            ),
          ],
        ),
      );
      if (exit == true) {
        try {
          await const MethodChannel(
            'hu_hs/radio',
          ).invokeMethod<void>('closeApp');
        } on MissingPluginException {
          await SystemNavigator.pop();
        }
      }
    } finally {
      _exitDialogOpen = false;
    }
  }

  void _selectTab(int index) {
    if (index == _currentIndex) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      _setCurrentIndex(index);
    }
  }

  Future<void> _handleSystemBack() async {
    final now = DateTime.now();
    final lastBack = _lastSystemBackAt;
    if (_backHandling ||
        (lastBack != null &&
            now.difference(lastBack) < const Duration(milliseconds: 500))) {
      return;
    }
    _lastSystemBackAt = now;
    _backHandling = true;
    try {
      final navigator = _navigatorKeys[_currentIndex].currentState;
      // NavigatorPopHandler normally consumes child-route back actions. Keep
      // this fallback for a navigation notification arriving one frame late,
      // but never pop a tab's root route: that is what caused blank tabs and
      // the apparent app exit in the previous implementation.
      if (navigator != null && navigator.canPop()) {
        if (await navigator.maybePop()) return;
      }
      if (!mounted) return;
      if (_currentIndex != 0) {
        _setCurrentIndex(0);
        return;
      }
      await _confirmExit();
    } finally {
      _backHandling = false;
    }
  }

  Widget _portraitNavigationBar() => NavigationBar(
    selectedIndex: _currentIndex,
    onDestinationSelected: _selectTab,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Kezdőlap',
      ),
      NavigationDestination(
        icon: Icon(Icons.article_outlined),
        selectedIcon: Icon(Icons.article),
        label: 'Hírek',
      ),
      NavigationDestination(
        icon: Icon(Icons.event_outlined),
        selectedIcon: Icon(Icons.event),
        label: 'Események',
      ),
      NavigationDestination(
        icon: Icon(Icons.forum_outlined),
        selectedIcon: Icon(Icons.forum),
        label: 'Chat',
      ),
      NavigationDestination(
        icon: Icon(Icons.album_outlined),
        selectedIcon: Icon(Icons.album),
        label: 'Label',
      ),
      NavigationDestination(icon: Icon(Icons.menu), label: 'Több'),
    ],
  );

  Widget _landscapeNavigationRail() => NavigationRail(
    selectedIndex: _currentIndex,
    onDestinationSelected: _selectTab,
    scrollable: true,
    labelType: NavigationRailLabelType.all,
    useIndicator: true,
    destinations: const [
      NavigationRailDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: Text('Kezdőlap'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.article_outlined),
        selectedIcon: Icon(Icons.article),
        label: Text('Hírek'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.event_outlined),
        selectedIcon: Icon(Icons.event),
        label: Text('Események'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.forum_outlined),
        selectedIcon: Icon(Icons.forum),
        label: Text('Chat'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.album_outlined),
        selectedIcon: Icon(Icons.album),
        label: Text('Label'),
      ),
      NavigationRailDestination(icon: Icon(Icons.menu), label: Text('Több')),
    ],
  );

  double _landscapeBottomInset(BuildContext context) {
    final media = MediaQuery.of(context);
    return math.max(
      media.viewPadding.bottom,
      math.max(media.padding.bottom, media.systemGestureInsets.bottom),
    );
  }

  @override
  Widget build(BuildContext context) {
    _tabFor(_currentIndex);
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_handleSystemBack());
      },
      child: OrientationBuilder(
        builder: (context, orientation) {
          final landscape = orientation == Orientation.landscape;
          return Scaffold(
            body: landscape
                ? SafeArea(
                    bottom: true,
                    child: Row(
                      children: [
                        _landscapeNavigationRail(),
                        const SizedBox(width: 1, height: 1),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(child: _contentStack()),
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: _landscapeBottomInset(context) + 12,
                                ),
                                child: const RadioPlayerBar(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : _contentStack(),
            bottomNavigationBar: landscape
                ? SizedBox(width: 1, height: 1, child: _portraitNavigationBar())
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const RadioPlayerBar(),
                      _portraitNavigationBar(),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
