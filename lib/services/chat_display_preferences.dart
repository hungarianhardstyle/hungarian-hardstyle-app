import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatDisplayPreferences {
  static const achievementInChatKey = 'achievement_in_chat_enabled';
  static final achievementInChat = ValueNotifier<bool>(true);
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    final preferences = await SharedPreferences.getInstance();
    achievementInChat.value = preferences.getBool(achievementInChatKey) ?? true;
    _loaded = true;
  }

  static Future<void> setAchievementInChat(bool value) async {
    achievementInChat.value = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(achievementInChatKey, value);
    _loaded = true;
  }
}
