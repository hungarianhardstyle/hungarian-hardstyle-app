import 'package:flutter/material.dart';

import 'events/events_screen.dart';
import 'community/community_screen.dart';
import 'home/home_screen.dart';
import 'more/more_screen.dart';
import 'news/news_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());
  final _tabs = List<Widget?>.filled(5, null);

  void _openNewsTab() => setState(() => _currentIndex = 1);

  Widget _tabNavigator(int index) {
    return Navigator(
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
            default:
              return const MoreScreen();
          }
        },
      ),
    );
  }

  Widget _tabFor(int index) => _tabs[index] ??= _tabNavigator(index);

  @override
  Widget build(BuildContext context) {
    _tabFor(_currentIndex);

    return PopScope<void>(
      // A rendszer-vissza ne zárja be az appot a fő navigációs héjból.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final navigator = _navigatorKeys[_currentIndex].currentState;
        if (navigator?.canPop() ?? false) {
          navigator!.pop();
        } else if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(
            5,
            (index) => _tabs[index] ?? const SizedBox.shrink(),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            if (index == _currentIndex) {
              _navigatorKeys[index].currentState?.popUntil(
                (route) => route.isFirst,
              );
            } else {
              setState(() => _currentIndex = index);
            }
          },
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
              label: 'Live Feed',
            ),
            NavigationDestination(icon: Icon(Icons.menu), label: 'Több'),
          ],
        ),
      ),
    );
  }
}
