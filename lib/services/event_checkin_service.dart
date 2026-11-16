import 'package:cloud_functions/cloud_functions.dart';

import '../core/firebase/firebase_callable.dart';

/// A becsekkolás eredménye (a szerver válasza).
class EventCheckinResult {
  final int eventId;
  final String title;
  final String badgeName;
  final String badgeUrl;
  final bool alreadyCheckedIn;
  final int points;

  const EventCheckinResult({
    required this.eventId,
    required this.title,
    required this.badgeName,
    required this.badgeUrl,
    required this.alreadyCheckedIn,
    required this.points,
  });

  factory EventCheckinResult.fromJson(Map<String, dynamic> json) {
    String text(String key) => (json[key] ?? '').toString();
    return EventCheckinResult(
      eventId: (json['eventId'] as num?)?.toInt() ?? 0,
      title: text('title'),
      badgeName: text('badgeName'),
      badgeUrl: text('badgeUrl'),
      alreadyCheckedIn: json['alreadyCheckedIn'] == true,
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A QR tartalma a saját becsekkolási linkünk-e (a szerver is ellenőrzi; ez csak
/// a felesleges hívás elkerülésére és a gyors visszajelzésre van).
bool looksLikeCheckinQr(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  if (host != 'hungarianhardstyle.hu' && host != 'www.hungarianhardstyle.hu') {
    return false;
  }
  return RegExp(r'^/checkin/\d+/[A-Za-z0-9]+/?$').hasMatch(uri.path);
}

typedef CheckinCaller = Future<Map<String, dynamic>> Function(String qr);

Future<Map<String, dynamic>> _callCheckin(String qr) async {
  final response = await callFirebaseCallable<Map<String, dynamic>>(
    'checkInEvent',
    parameters: {'qr': qr},
  );
  return Map<String, dynamic>.from(response.data);
}

class EventCheckinService {
  EventCheckinService({CheckinCaller? caller}) : _caller = caller ?? _callCheckin;

  final CheckinCaller _caller;

  /// A szerver magyar hibaüzenetét adja tovább ([EventCheckinException]).
  Future<EventCheckinResult> checkIn(String qr) async {
    if (!looksLikeCheckinQr(qr)) {
      throw const EventCheckinException(
        'Ez nem egy Hungarian Hardstyle becsekkolási QR-kód.',
      );
    }
    try {
      return EventCheckinResult.fromJson(await _caller(qr.trim()));
    } on FirebaseFunctionsException catch (error) {
      throw EventCheckinException(
        (error.message ?? '').trim().isNotEmpty
            ? error.message!.trim()
            : 'A becsekkolás most nem sikerült, próbáld újra.',
      );
    }
  }
}

class EventCheckinException implements Exception {
  final String message;
  const EventCheckinException(this.message);

  @override
  String toString() => message;
}
