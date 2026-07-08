import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'screens/main_navigation.dart';

void main() {
  runApp(
    const ProviderScope(
      child: HungarianHardstyleApp(),
    ),
  );
}

class HungarianHardstyleApp extends StatelessWidget {
  const HungarianHardstyleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hungarian Hardstyle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: MainNavigation(),
    );
  }
}