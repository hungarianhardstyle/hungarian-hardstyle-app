import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/twitch_chat.dart';

/// A stream-chat szolgáltatása — a felület ezen keresztül ér el mindent.
///
/// ⚠️ MIÉRT provider: a **widget-teszt** ezt felülírja egy hamis átjáróval
/// (`TwitchChatGateway`), ezért a stream-chat kirajzolása és a küldés is mérhető
/// Firestore nélkül.
final twitchChatServiceProvider = Provider<TwitchChatGateway>(
  (ref) => TwitchChatService(),
);

/// A legfrissebb stream-chat üzenetek (élő).
final twitchChatMessagesProvider =
    StreamProvider.autoDispose<List<TwitchChatMessage>>(
  (ref) => ref.watch(twitchChatServiceProvider).watchMessages(),
);
