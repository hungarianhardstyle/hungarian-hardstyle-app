import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr.dart';
import '../../providers/twitch_chat_provider.dart';
import '../../services/twitch_chat.dart';
import '../../widgets/app_text.dart';
import '../../widgets/chat_emoji_button.dart';
import '../../widgets/keyboard_dismiss_button.dart';

/// **A Twitch-oldal alatti chat** — külön szálon (391).
///
/// A tulajdonos jelzése (2026-10-02): *„a twitch oldal alatti chatr ha írok,
/// valamiért a fő chatre is kikerül...”*. A mért gyökér az volt, hogy a
/// Twitch-oldal a **fő chat** widgetjét használta (ugyanaz a `live_feed_posts`
/// gyűjtemény). Ez a widget a saját, külön szálat rajzolja ki
/// ([twitchChatCollection]) — a fő chat érintetlen marad.
///
/// Szándékosan egyszerű: szöveg, név, avatár, időpont. Nincs reakció, emoji,
/// `@`hivatkozás és **nincs push** (a részletek: `services/twitch_chat.dart`).
class TwitchStreamChat extends ConsumerStatefulWidget {
  const TwitchStreamChat({super.key});

  @override
  ConsumerState<TwitchStreamChat> createState() => _TwitchStreamChatState();
}

class _TwitchStreamChatState extends ConsumerState<TwitchStreamChat> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// A kiválasztott emotikon beszúrása a kurzor helyére (a meglévő, bizonyított
  /// segédfüggvénnyel — a fő chat is ezt használja).
  Future<void> _pickEmoji() async {
    final emoji = await showChatEmojiPicker(context);
    if (emoji == null) return;
    insertChatEmoji(_controller, emoji, focusNode: _focusNode);
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(message)));
  }

  Future<void> _send() async {
    final text = twitchChatOutgoingText(_controller.text);
    if (text == null) {
      _say(tr(context, 'Írj egy rövid üzenetet (legfeljebb 500 karakter).'));
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(twitchChatServiceProvider).send(text);
      _controller.clear();
    } catch (_) {
      if (!mounted) return;
      _say(tr(context, 'Az üzenet nem ment el. Próbáld újra.'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(twitchChatMessagesProvider);
    return Column(
      children: [
        _ChatHeader(),
        Expanded(
          child: messages.when(
            data: (list) => list.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: AppText('Még nincs üzenet a stream alatt — írj te először!'),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: list.length,
                    itemBuilder: (context, index) => _MessageRow(message: list[index]),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: AppText('A stream-chat most nem érhető el.'),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => unawaited(_send()),
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    hintText: tr(context, 'Írj valamit a közösségnek…'),
                  ),
                ),
              ),
              // EMOTIKON (394) — a tulajdonos jelzése: *„+ nincsenek emotok”*. A
              // fő chatnél ez a gomb szándékosan csak iOS-en látszik (Androidon a
              // rendszerbillentyűzeten van emoji-kulcs), itt viszont **mindkét
              // platformon** kérjük, ezért itt mindig megjelenik.
              IconButton(
                tooltip: tr(context, 'Emotikon'),
                onPressed: () => unawaited(_pickEmoji()),
                icon: const Icon(Icons.emoji_emotions_outlined),
              ),
              // BILLENTYŰZET-ELREJTŐ (394) — a tulajdonos jelzése: *„eltűnt a
              // billenytűzet eltűntető gomb is”*. Ugyanaz a bizonyított widget,
              // mint a fő chatnél (csak nyitott billentyűzetnél látszik).
              const KeyboardDismissButton(),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _sending ? null : () => unawaited(_send()),
                icon: const Icon(Icons.send, size: 18),
                label: const AppText('Küldés'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A stream-chat fejléce — **kimondja**, hogy ez külön szál (a tulajdonos
/// jelzésére: eddig észrevétlenül a fő chatbe ment az üzenet).
class _ChatHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          const Icon(Icons.forum_outlined, size: 16),
          const SizedBox(width: 8),
          const AppText(
            'Stream-chat',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppText(
              'külön szál — a fő chat nem kapja meg',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Egy üzenet sora: avatár, név, időpont, szöveg.
class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message});

  final TwitchChatMessage message;

  String get _time {
    final local = message.createdAt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final url = message.authorImageUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: url.isEmpty ? null : NetworkImage(url),
            child: url.isEmpty ? const Icon(Icons.person, size: 16) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: AppText(
                        message.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppText(
                      _time,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                AppText(message.text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
