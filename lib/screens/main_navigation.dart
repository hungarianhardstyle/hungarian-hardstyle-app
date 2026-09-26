import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'events/events_screen.dart';
import 'community/community_screen.dart';
import 'home/home_screen.dart';
import 'more/more_screen.dart';
import 'news/news_screen.dart';
import 'releases/releases_screen.dart';
import '../core/i18n/tr.dart';
import '../providers/news_provider.dart';
import '../widgets/app_text.dart';
import '../widgets/radio_player_bar.dart';
import '../services/app_badge_sync.dart';
import '../services/app_update_service.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation>
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
  bool _updateRetryScheduled = false;
  bool _exitDialogOpen = false;
  bool _backHandling = false;
  DateTime? _lastSystemBackAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
    // Az app-ikon jelvénye (olvasatlan értesítések száma) a teljes munkamenet
    // alatt figyelve van, mert ez a képernyő sosem tűnik el.
    _badgeSync = AppBadgeSync();
  }

  AppBadgeSync? _badgeSync;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _badgeSync?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForUpdate();
      // ⚠️ MÉRT OK (2026-09-26): a push-értesítésre megnyitott app **azonnal**
      // kérdezze meg a szervert, ne várjon a percenkénti ütemre — a plugin a
      // publikáláskor azonnal érvényteleníti a cache-ét, és a kondicionális HEAD
      // 304-et ad (mért: 399 ms, 0 bájt), tehát ez egy olcsó kérés. A csendes
      // út nem ír a képernyőre: változáskor a jelzés frissíti a listákat.
      unawaited(ref.read(newsRevalidateProvider)());
    }
  }

  Future<void> _checkForUpdate({bool retryWhenMissing = true}) async {
    if (_checkingUpdate || _updateDialogOpen || !mounted) return;
    _checkingUpdate = true;
    try {
      final info = await AppUpdateService().check();
      if (info == null) {
        if (retryWhenMissing && mounted && !_updateRetryScheduled) {
          _updateRetryScheduled = true;
          Future<void>.delayed(const Duration(seconds: 4), () {
            _updateRetryScheduled = false;
            if (mounted) _checkForUpdate(retryWhenMissing: false);
          });
        }
        return;
      }
      if (!mounted || _updateDialogOpen) return;
      _updateDialogOpen = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const AppText('Új verzió érhető el'),
          content: const AppText(
            'Frissítsd az alkalmazást a legújabb javításokért.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const AppText('Most nem'),
            ),
            FilledButton(
              onPressed: () async {
                await AppUpdateService().start(info);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const AppText('Frissítés'),
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

  void _openNewsTab() {
    _navigatorKeys[1].currentState?.popUntil((route) => route.isFirst);
    _setCurrentIndex(1);
  }

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
              return LiveFeedScreen(
                onProfileDeleted: () => _setCurrentIndex(0),
              );
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
          title: const AppText('Kilépés'),
          content: const AppText('Biztosan ki szeretnél lépni az alkalmazásból?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const AppText('Mégse'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const AppText('Kilépés'),
            ),
          ],
        ),
      );
      if (exit == true) {
        try {
          await const MethodChannel('hu_hs/radio')
              .invokeMethod<void>('closeApp');
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

  Widget _navGraphic(String asset, {bool selected = false}) => Opacity(
    opacity: selected ? 1 : .72,
    child: Image.asset(
      'assets/images/$asset.png',
      width: 34,
      height: 34,
      fit: BoxFit.contain,
    ),
  );

  Widget _portraitNavigationBar() => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: _selectTab,
      destinations: [
        NavigationDestination(
          icon: _navGraphic('nav_home'),
          selectedIcon: _navGraphic('nav_home', selected: true),
          label: tr(context, 'Kezdőlap'),
        ),
        NavigationDestination(
          icon: _navGraphic('nav_news'),
          selectedIcon: _navGraphic('nav_news', selected: true),
          label: tr(context, 'Hírek'),
        ),
        NavigationDestination(
          icon: _navGraphic('nav_events'),
          selectedIcon: _navGraphic('nav_events', selected: true),
          label: tr(context, 'Események'),
        ),
        NavigationDestination(
          icon: _navGraphic('nav_chat'),
          selectedIcon: _navGraphic('nav_chat', selected: true),
          label: tr(context, 'Chat'),
        ),
        NavigationDestination(
          icon: _navGraphic('nav_label'),
          selectedIcon: _navGraphic('nav_label', selected: true),
          label: tr(context, 'Label'),
        ),
        NavigationDestination(
          icon: _navGraphic('nav_more'),
          selectedIcon: _navGraphic('nav_more', selected: true),
          label: tr(context, 'Több'),
        ),
      ],
    ),
  );

  Widget _landscapeNavigationRail() => NavigationRail(
    selectedIndex: _currentIndex,
    onDestinationSelected: _selectTab,
    scrollable: true,
    labelType: NavigationRailLabelType.all,
    useIndicator: true,
    destinations: [
      NavigationRailDestination(
        icon: _navGraphic('nav_home'),
        selectedIcon: _navGraphic('nav_home', selected: true),
        label: AppText('Kezdőlap'),
      ),
      NavigationRailDestination(
        icon: _navGraphic('nav_news'),
        selectedIcon: _navGraphic('nav_news', selected: true),
        label: AppText('Hírek'),
      ),
      NavigationRailDestination(
        icon: _navGraphic('nav_events'),
        selectedIcon: _navGraphic('nav_events', selected: true),
        label: AppText('Események'),
      ),
      NavigationRailDestination(
        icon: _navGraphic('nav_chat'),
        selectedIcon: _navGraphic('nav_chat', selected: true),
        label: AppText('Chat'),
      ),
      NavigationRailDestination(
        icon: _navGraphic('nav_label'),
        selectedIcon: _navGraphic('nav_label', selected: true),
        label: AppText('Label'),
      ),
      NavigationRailDestination(
        icon: _navGraphic('nav_more'),
        label: AppText('Több'),
      ),
    ],
  );

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
                        Expanded(child: _contentStack()),
                      ],
                    ),
                  )
                : _contentStack(),
            bottomNavigationBar: landscape
                ? const SafeArea(top: false, child: RadioPlayerBar())
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
