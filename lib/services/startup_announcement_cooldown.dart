import 'package:shared_preferences/shared_preferences.dart';

class StartupAnnouncementCooldown {
  static const duration = Duration(hours: 2);
  static const _prefix = 'huhs.startup.announcement';

  const StartupAnnouncementCooldown();

  Future<bool> canShow({
    required String identity,
    required String ownerId,
    DateTime? now,
  }) async {
    final normalizedIdentity = identity.trim();
    if (normalizedIdentity.isEmpty) return false;
    final preferences = await SharedPreferences.getInstance();
    final key = _key(ownerId);
    if (preferences.getString('$key.identity') != normalizedIdentity) {
      return true;
    }
    final lastShown = preferences.getInt('$key.shownAt');
    if (lastShown == null) return true;
    final elapsed = (now ?? DateTime.now()).difference(
      DateTime.fromMillisecondsSinceEpoch(lastShown),
    );
    return elapsed.isNegative || elapsed >= duration;
  }

  Future<void> markShown({
    required String identity,
    required String ownerId,
    DateTime? now,
  }) async {
    final normalizedIdentity = identity.trim();
    if (normalizedIdentity.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final key = _key(ownerId);
    await preferences.setString('$key.identity', normalizedIdentity);
    await preferences.setInt(
      '$key.shownAt',
      (now ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  String _key(String ownerId) {
    final normalizedOwner = ownerId.trim().isEmpty ? 'device' : ownerId.trim();
    return '$_prefix.${Uri.encodeComponent(normalizedOwner)}';
  }
}
