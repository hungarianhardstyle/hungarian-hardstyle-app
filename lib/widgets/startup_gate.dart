import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/main_navigation.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
      lowerBound: .88,
      upperBound: 1,
      value: .88,
    )..repeat(reverse: true);
    _timer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _ready = true);
    });
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
    if (_ready) return const MainNavigation();

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
            'assets/logos/huhs_full_logo.png',
            width: MediaQuery.sizeOf(context).width * .82,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
