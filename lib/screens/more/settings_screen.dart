import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:otp/otp.dart';

import '../../services/push_notification_service.dart';
import '../../services/community_service.dart';

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
  bool _biometricEnabled = false;
  bool _deviceCodeEnabled = false;
  bool _authenticatorEnabled = false;

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
      _biometricEnabled = preferences.getBool('biometric_unlock') ?? false;
      _deviceCodeEnabled = preferences.getBool('device_code_unlock') ?? false;
      _authenticatorEnabled =
          preferences.getBool('authenticator_unlock') ?? false;
      _loading = false;
    });
  }

  Future<void> _setDeviceCode(bool value) async {
    if (value && !await CommunityService().authenticateDeviceCode()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A telefonos kódos feloldás nem sikerült.'),
          ),
        );
      }
      return;
    }
    await CommunityService().setDeviceCodeEnabled(value);
    if (mounted) setState(() => _deviceCodeEnabled = value);
  }

  Future<void> _setupAuthenticator() async {
    final service = CommunityService();
    var secret = await service.authenticatorSecret();
    if (secret == null || secret.isEmpty) {
      secret = OTP.randomSecret();
      await service.setAuthenticatorSecret(secret);
    }
    if (!mounted) return;
    final controller = TextEditingController();
    final verified = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Authenticator beállítása'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add meg ezt a kulcsot a Google Authenticatorban:'),
            const SizedBox(height: 10),
            SelectableText(
              secret!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '6 számjegyű kód'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim().length == 6,
            ),
            child: const Text('Ellenőrzés'),
          ),
        ],
      ),
    );
    final valid =
        verified == true &&
        await service.verifyAuthenticatorCode(controller.text);
    controller.dispose();
    if (!valid) {
      await service.setAuthenticatorEnabled(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A kód nem érvényes. Az authenticator nem lett bekapcsolva.',
            ),
          ),
        );
      }
      return;
    }
    if (mounted) setState(() => _authenticatorEnabled = true);
  }

  Future<void> _setAuthenticator(bool value) async {
    if (value) {
      await _setupAuthenticator();
    } else {
      await CommunityService().setAuthenticatorEnabled(false);
      if (mounted) setState(() => _authenticatorEnabled = false);
    }
  }

  Future<void> _setBiometric(bool value) async {
    if (value && !await CommunityService().authenticateBiometric()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A biometrikus feloldás nem érhető el. Engedélyezd a telefon beállításaiban.',
            ),
          ),
        );
      }
      return;
    }
    await CommunityService().setBiometricEnabled(value);
    if (mounted) setState(() => _biometricEnabled = value);
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final landscape =
                MediaQuery.orientationOf(context) == Orientation.landscape;
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: landscape ? 900 : double.infinity,
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
                      child: SwitchListTile(
                        secondary: const Icon(Icons.password_outlined),
                        title: const Text('Android-kódos feloldás'),
                        subtitle: const Text(
                          'A telefon PIN-kódjával, jelszavával vagy mintájával',
                        ),
                        value: _deviceCodeEnabled,
                        onChanged: _loading ? null : _setDeviceCode,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: SwitchListTile(
                        secondary: const Icon(Icons.lock_clock_outlined),
                        title: const Text('Google Authenticator'),
                        subtitle: const Text(
                          'Csak e-mail/jelszavas fióknál használható',
                        ),
                        value: _authenticatorEnabled,
                        onChanged: _loading ? null : _setAuthenticator,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: SwitchListTile(
                        secondary: const Icon(Icons.fingerprint),
                        title: const Text('Biometrikus feloldás'),
                        subtitle: const Text(
                          'A mentett profil feloldása ujjlenyomattal vagy arcfelismeréssel',
                        ),
                        value: _biometricEnabled,
                        onChanged: _loading ? null : _setBiometric,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.article_outlined),
                            title: const Text('Új hírek'),
                            subtitle: const Text(
                              'Értesítés új hír közzétételekor',
                            ),
                            value: _newsNotificationsEnabled,
                            onChanged: _loading || !_notificationsEnabled
                                ? null
                                : (value) {
                                    setState(
                                      () => _newsNotificationsEnabled = value,
                                    );
                                    _setNotificationPreference(
                                      _newsNotificationsKey,
                                      value,
                                    );
                                  },
                          ),
                          SwitchListTile(
                            secondary: const Icon(Icons.event_outlined),
                            title: const Text('Új események'),
                            subtitle: const Text(
                              'Értesítés új esemény közzétételekor',
                            ),
                            value: _eventNotificationsEnabled,
                            onChanged: _loading || !_notificationsEnabled
                                ? null
                                : (value) {
                                    setState(
                                      () => _eventNotificationsEnabled = value,
                                    );
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
                                      () =>
                                          _reminderNotificationsEnabled = value,
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
          },
        ),
      ),
    );
  }
}
