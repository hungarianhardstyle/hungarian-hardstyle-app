import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/theme/app_theme.dart';
import 'screens/main_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('hu_HU');
  await MobileAds.instance.initialize();
  runApp(const ProviderScope(child: HungarianHardstyleApp()));
}

class HungarianHardstyleApp extends StatelessWidget {
  const HungarianHardstyleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hungarian Hardstyle',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.darkTheme,

      locale: const Locale('hu', 'HU'),

      supportedLocales: const [Locale('hu', 'HU')],

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const MainNavigation(),
    );
  }
}
