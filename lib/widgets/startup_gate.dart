import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/main_navigation.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate>
    with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 850);
  static const _startupDelay = Duration(milliseconds: 700);
  static const _logoAsset = 'assets/logos/huhs_full_logo.png';

  late final AnimationController _controller;
  Timer? _timer;
  bool _ready = false;
  String? _announcementUrl;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
      lowerBound: .88,
      upperBound: 1,
      value: .88,
    )..repeat(reverse: true);
    _timer = Timer(_startupDelay, () {
      if (mounted) setState(() => _ready = true);
    });
    _loadAnnouncement();
  }

  Future<void> _loadAnnouncement() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final snapshot = await FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'hungarian-hardstyle',
      ).collection('app_settings').doc('startup').get();
      final data = snapshot.data();
      if (data?['enabled'] == true && data?['imageUrl'] is String) {
        final imageUrl = data!['imageUrl'] as String;
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString('startup_announcement_dismissed') != imageUrl && mounted) {
          setState(() => _announcementUrl = imageUrl);
        }
      }
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = 1;
      _timer?.cancel();
      _ready = true;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      final home = const MainNavigation();
      if (_announcementUrl == null) return home;
      return Stack(
        children: [
          home,
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black87,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(24),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.network(_announcementUrl!, fit: BoxFit.contain),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString(
                              'startup_announcement_dismissed',
                              _announcementUrl!,
                            );
                            if (mounted) setState(() => _announcementUrl = null);
                          },
                          child: const Text('Bezárás'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.scale(
            scale: _controller.value,
            child: child,
          ),
          child: Image.asset(
            _logoAsset,
            width: MediaQuery.sizeOf(context).width * .82,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
