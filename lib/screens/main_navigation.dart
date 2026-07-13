import 'package:flutter/material.dart';

import 'events/events_screen.dart';
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

  final _navigatorKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());
  final _tabs = List<Widget?>.filled(4, null);

  void _openNewsTab() {
    setState(() => _currentIndex = 1);
  }

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
            default:
              return const MoreScreen();
          }
        },
      ),
    );
  }

  Widget _tabFor(int index) {
    return _tabs[index] ??= _tabNavigator(index);
  }

  @override
  Widget build(BuildContext context) {
    _tabFor(_currentIndex);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(
          4,
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
          NavigationDestination(icon: Icon(Icons.menu), label: 'Több'),
        ],
      ),
    );
  }
}
