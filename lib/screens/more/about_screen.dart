import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/navigation/in_app_browser.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Az appról')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final version = info == null
                  ? 'Verzió betöltése…'
                  : '${info.version}+${info.buildNumber}';

              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const Icon(
                    Icons.graphic_eq,
                    size: 72,
                    color: Color(0xFFE53935),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Hungarian Hardstyle',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Magyar hardstyle és hardcore közösségi app',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _InfoTile(
                    icon: Icons.info_outline,
                    label: 'Verzió',
                    value: version,
                  ),
                  _InfoTile(
                    icon: Icons.language,
                    label: 'Weboldal',
                    value: 'hungarianhardstyle.hu',
                    onTap: () => openInAppBrowser(
                      context,
                      'https://hungarianhardstyle.hu',
                    ),
                  ),
                  _InfoTile(
                    icon: Icons.mail_outline,
                    label: 'Kapcsolat',
                    value: 'info@hungarianhardstyle.hu',
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
        trailing: onTap == null ? null : const Icon(Icons.open_in_new),
        onTap: onTap,
      ),
    );
  }
}
