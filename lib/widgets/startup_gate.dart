import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
  String? _dismissedAnnouncementUrl;

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
    try {
      final response = await Dio().get<Map<String, dynamic>>(
        'https://hungarianhardstyle.hu/wp-json/huhs/v1/startup-announcement',
        queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
        options: Options(headers: const {'Cache-Control': 'no-cache'}),
      );
      final data = response.data;
      final imageUrl = (data?['imageUrl'] as String?)?.trim();
      if (!mounted) return;
      setState(() {
        _announcementUrl =
            data?['enabled'] == true &&
                imageUrl != null &&
                imageUrl.isNotEmpty &&
                imageUrl != _dismissedAnnouncementUrl
            ? imageUrl
            : null;
      });
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
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .82,
                            maxHeight: MediaQuery.sizeOf(context).height * .62,
                          ),
                          child: Image.network(
                            _announcementUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.image_not_supported_outlined,
                              size: 56,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                _dismissedAnnouncementUrl = _announcementUrl;
                                _announcementUrl = null;
                              });
                            }
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
          builder: (context, child) =>
              Transform.scale(scale: _controller.value, child: child),
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
