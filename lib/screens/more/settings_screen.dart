import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/push_notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _notificationsKey = 'notifications_enabled';
  static const _newsNotificationsKey = 'news_notifications_enabled';
  static const _eventNotificationsKey = 'event_notifications_enabled';
  static const _reminderNotificationsKey = 'event_reminders_enabled';

  bool _notificationsEnabled = true;
  bool _newsNotificationsEnabled = true;
  bool _eventNotificationsEnabled = true;
  bool _reminderNotificationsEnabled = true;
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
      _newsNotificationsEnabled =
          preferences.getBool(_newsNotificationsKey) ?? true;
      _eventNotificationsEnabled =
          preferences.getBool(_eventNotificationsKey) ?? true;
      _reminderNotificationsEnabled =
          preferences.getBool(_reminderNotificationsKey) ?? true;
      _loading = false;
    });
  }

  Future<void> _setNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_notificationsKey, value);
    unawaited(_syncNotificationPreferences());
  }

  Future<void> _setNotificationPreference(String key, bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, value);
    unawaited(_syncNotificationPreferences());
  }

  Future<void> _syncNotificationPreferences() =>
      PushNotificationService.updatePreferences(
        enabled: _notificationsEnabled,
        news: _newsNotificationsEnabled,
        events: _eventNotificationsEnabled,
        reminders: _reminderNotificationsEnabled,
      );

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
                      : 'Összes értesítés ki- és bekapcsolása',
                ),
                value: _notificationsEnabled,
                onChanged: _loading ? null : _setNotifications,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.article_outlined),
                    title: const Text('Új hírek'),
                    subtitle: const Text('Értesítés új hír közzétételekor'),
                    value: _newsNotificationsEnabled,
                    onChanged: _loading || !_notificationsEnabled
                        ? null
                        : (value) {
                            setState(() => _newsNotificationsEnabled = value);
                            _setNotificationPreference(
                              _newsNotificationsKey,
                              value,
                            );
                          },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.event_outlined),
                    title: const Text('Új események'),
                    subtitle: const Text('Értesítés új esemény közzétételekor'),
                    value: _eventNotificationsEnabled,
                    onChanged: _loading || !_notificationsEnabled
                        ? null
                        : (value) {
                            setState(() => _eventNotificationsEnabled = value);
                            _setNotificationPreference(
                              _eventNotificationsKey,
                              value,
                            );
                          },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.alarm_outlined),
                    title: const Text('Esemény-emlékeztetők'),
                    subtitle: const Text('Egy héttel előtte és aznap'),
                    value: _reminderNotificationsEnabled,
                    onChanged: _loading || !_notificationsEnabled
                        ? null
                        : (value) {
                            setState(
                              () => _reminderNotificationsEnabled = value,
                            );
                            _setNotificationPreference(
                              _reminderNotificationsKey,
                              value,
                            );
                          },
                  ),
                ],
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
