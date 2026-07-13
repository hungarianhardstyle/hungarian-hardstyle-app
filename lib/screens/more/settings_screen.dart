import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _notificationsKey = 'notifications_enabled';

  bool _notificationsEnabled = true;
  bool _loading = true;
  bool _clearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _notificationsEnabled = preferences.getBool(_notificationsKey) ?? true;
      _loading = false;
    });
  }

  Future<void> _setNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_notificationsKey, value);
  }

  Future<void> _clearCache() async {
    setState(() => _clearingCache = true);
    await DefaultCacheManager().emptyCache();
    PaintingBinding.instance.imageCache.clear();
    if (!mounted) return;
    setState(() => _clearingCache = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('A gyorsítótár törölve.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beállítások')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('Értesítések'),
                subtitle: Text(
                  _loading
                      ? 'Beállítás betöltése…'
                      : 'Értesítési engedélyek előkészítése',
                ),
                value: _notificationsEnabled,
                onChanged: _loading ? null : _setNotifications,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(Icons.cleaning_services_outlined),
                title: Text('Gyorsítótár'),
                subtitle: Text(
                  'A képek gyorsítótárát az app automatikusan kezeli.',
                ),
                trailing: Icon(Icons.delete_outline),
                onTap: _clearingCache ? null : _clearCache,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
