import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:otp/otp.dart';

import '../../core/i18n/tr.dart';
import '../../services/push_notification_service.dart';
import '../../services/community_service.dart';
import '../../services/chat_display_preferences.dart';
import '../../services/wordpress_service.dart';
import '../../widgets/app_text.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _notificationsKey = 'notifications_enabled';
  static const _newsNotificationsKey = 'news_notifications_enabled';
  static const _eventNotificationsKey = 'event_notifications_enabled';
  static const _releaseNotificationsKey = 'release_notifications_enabled';
  static const _reminderNotificationsKey = 'event_reminders_enabled';
  static const _achievementNotificationsKey =
      'achievement_notifications_enabled';

  bool _notificationsEnabled = true;
  bool _newsNotificationsEnabled = true;
  bool _eventNotificationsEnabled = true;
  bool _releaseNotificationsEnabled = true;
  bool _reminderNotificationsEnabled = true;
  bool _achievementNotificationsEnabled = true;
  bool _loading = true;
  bool _clearingCache = false;
  bool _biometricEnabled = false;
  bool _deviceCodeEnabled = false;
  bool _authenticatorEnabled = false;

  @override
  void initState() {
    super.initState();
    ChatDisplayPreferences.load();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;

    var biometricEnabled = preferences.getBool('biometric_unlock') ?? false;
    var deviceCodeEnabled = preferences.getBool('device_code_unlock') ?? false;
    if (biometricEnabled && deviceCodeEnabled) {
      deviceCodeEnabled = false;
      await preferences.setBool('device_code_unlock', false);
    }

    setState(() {
      _notificationsEnabled = preferences.getBool(_notificationsKey) ?? true;
      _newsNotificationsEnabled =
          preferences.getBool(_newsNotificationsKey) ?? true;
      _eventNotificationsEnabled =
          preferences.getBool(_eventNotificationsKey) ?? true;
      _releaseNotificationsEnabled =
          preferences.getBool(_releaseNotificationsKey) ?? true;
      _reminderNotificationsEnabled =
          preferences.getBool(_reminderNotificationsKey) ?? true;
      _achievementNotificationsEnabled =
          preferences.getBool(_achievementNotificationsKey) ?? true;
      _biometricEnabled = biometricEnabled;
      _deviceCodeEnabled = deviceCodeEnabled;
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
            content: AppText('A telefonos kódos feloldás nem sikerült.'),
          ),
        );
      }
      return;
    }
    await CommunityService().setDeviceCodeEnabled(value);
    if (mounted) {
      setState(() {
        _deviceCodeEnabled = value;
        if (value) _biometricEnabled = false;
      });
    }
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
        title: const AppText('Authenticator beállítása'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText('Add meg ezt a kulcsot a Google Authenticatorban:'),
            const SizedBox(height: 10),
            SelectableText(
              secret!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr(context, '6 számjegyű kód')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim().length == 6,
            ),
            child: const AppText('Ellenőrzés'),
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
            content: AppText(
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
            content: AppText(
              'A biometrikus feloldás nem érhető el. Engedélyezd a telefon beállításaiban.',
            ),
          ),
        );
      }
      return;
    }
    await CommunityService().setBiometricEnabled(value);
    if (mounted) {
      setState(() {
        _biometricEnabled = value;
        if (value) _deviceCodeEnabled = false;
      });
    }
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
        releases: _releaseNotificationsEnabled,
        reminders: _reminderNotificationsEnabled,
        achievements: _achievementNotificationsEnabled,
      );

  Future<void> _clearCache() async {
    setState(() => _clearingCache = true);
    await DefaultCacheManager().emptyCache();
    PaintingBinding.instance.imageCache.clear();
    await WordpressService().clearPublicCache();
    if (!mounted) return;
    setState(() => _clearingCache = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: AppText('A gyorsítótár törölve.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('Beállítások')),
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
                        title: const AppText('Értesítések'),
                        subtitle: Text(
                          _loading
                              ? tr(context, 'Beállítás betöltése…')
                              : tr(context, 'Összes értesítés ki- és bekapcsolása'),
                        ),
                        value: _notificationsEnabled,
                        onChanged: _loading ? null : _setNotifications,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ValueListenableBuilder<bool>(
                        valueListenable:
                            ChatDisplayPreferences.achievementInChat,
                        builder: (context, enabled, child) => SwitchListTile(
                          secondary: const Icon(
                            Icons.workspace_premium_outlined,
                          ),
                          title: const AppText('Achievement a chatben'),
                          subtitle: const AppText(
                            'A jelvény a felhasználó neve elé kerül, egy sorban',
                          ),
                          value: enabled,
                          onChanged:
                              ChatDisplayPreferences.setAchievementInChat,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: SwitchListTile(
                        secondary: const Icon(Icons.password_outlined),
                        title: const AppText('Android-kódos feloldás'),
                        subtitle: Text(
                          _deviceCodeEnabled
                              ? tr(context, 'A telefon PIN-kódjával, jelszavával vagy mintájával')
                              : tr(context, 'Kikapcsolva – koppints a bekapcsoláshoz'),
                        ),
                        value: _deviceCodeEnabled,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: const Color(0xFF555555),
                        onChanged: _loading ? null : _setDeviceCode,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: SwitchListTile(
                        secondary: const Icon(Icons.lock_clock_outlined),
                        title: const AppText('Google Authenticator'),
                        subtitle: const AppText(
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
                        title: const AppText('Biometrikus feloldás'),
                        subtitle: Text(
                          _biometricEnabled
                              ? tr(context, 'A mentett profil feloldása ujjlenyomattal vagy arcfelismeréssel')
                              : tr(context, 'Kikapcsolva – koppints a bekapcsoláshoz'),
                        ),
                        value: _biometricEnabled,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: const Color(0xFF555555),
                        onChanged: _loading ? null : _setBiometric,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.article_outlined),
                            title: const AppText('Új hírek'),
                            subtitle: const AppText(
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
                            title: const AppText('Új események'),
                            subtitle: const AppText(
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
                            secondary: const Icon(Icons.album_outlined),
                            title: const AppText('Új release-ek'),
                            subtitle: const AppText(
                              'Értesítés új release közzétételekor',
                            ),
                            value: _releaseNotificationsEnabled,
                            onChanged: _loading || !_notificationsEnabled
                                ? null
                                : (value) {
                                    setState(
                                      () =>
                                          _releaseNotificationsEnabled = value,
                                    );
                                    _setNotificationPreference(
                                      _releaseNotificationsKey,
                                      value,
                                    );
                                  },
                          ),
                          SwitchListTile(
                            secondary: const Icon(Icons.alarm_outlined),
                            title: const AppText('Esemény-emlékeztetők'),
                            subtitle: const AppText('Egy héttel előtte és aznap'),
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
                          SwitchListTile(
                            secondary: const Icon(
                              Icons.workspace_premium_outlined,
                            ),
                            title: const AppText('Achievement-szintlépések'),
                            subtitle: const AppText(
                              'Értesítés új rang vagy jelvény elérésekor',
                            ),
                            value: _achievementNotificationsEnabled,
                            onChanged: _loading || !_notificationsEnabled
                                ? null
                                : (value) {
                                    setState(
                                      () => _achievementNotificationsEnabled =
                                          value,
                                    );
                                    _setNotificationPreference(
                                      _achievementNotificationsKey,
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
                        title: AppText('Gyorsítótár'),
                        subtitle: AppText(
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
