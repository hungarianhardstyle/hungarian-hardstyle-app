import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/chat_mention_plan.dart';

/// A Chat-üzenet szövege **kattintható `@`-hivatkozásokkal**.
///
/// MIÉRT `Text.rich` és nem szöveg-parse: a `mentions` a **beíráskori nevet**
/// tartalmazza, a kattintás viszont az **azonosítóhoz** van kötve (uid, illetve
/// WordPress-azonosító) — így két azonos nevű felhasználónál is a helyes
/// célpontra visz, és az átnevezés sem töri el a régi üzenetet.
///
/// A megkeresés a tiszta [mentionSpans] függvényben van (ezért mérhető), ez a
/// widget csak kirajzolja a találatokat: a hivatkozás-tag a téma `primary`
/// színét kapja **aláhúzással**, a többi szöveg bitre ugyanaz, mint eddig.
///
/// ⚠️ MIÉRT `StatefulWidget`: a [TapGestureRecognizer] egy erőforrás, amit
/// **el kell dobni** — a `TextSpan` viszont nem `Widget`, ezért nem a
/// keretrendszer dispose-olja. A felismerőket ezért a példány tartja életben,
/// és a `dispose`-ban (illetve a szöveg/hivatkozások változásakor) zárja be.
class ChatMessageText extends StatefulWidget {
  const ChatMessageText({
    super.key,
    required this.text,
    required this.mentions,
    required this.onTap,
    this.style,
  });

  final String text;
  final List<ChatMentionTarget> mentions;
  final void Function(ChatMentionTarget target) onTap;
  final TextStyle? style;

  @override
  State<ChatMessageText> createState() => _ChatMessageTextState();
}

class _ChatMessageTextState extends State<ChatMessageText> {
  /// A szövegben **ténylegesen megtalált** hivatkozások (a tiszta modulból).
  List<MentionSpan> _spans = const <MentionSpan>[];

  /// A találatokhoz tartozó felismerők, **ugyanabban a sorrendben**, mint a
  /// [mentionSpans] eredménye.
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    _syncSpans();
  }

  @override
  void didUpdateWidget(covariant ChatMessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        !listEquals(oldWidget.mentions, widget.mentions)) {
      _syncSpans();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  /// A hivatkozások és a hozzájuk tartozó felismerők újraszámolása.
  void _syncSpans() {
    _disposeRecognizers();
    _spans = mentionSpans(widget.text, widget.mentions);
    for (final span in _spans) {
      final target = span.target;
      _recognizers.add(
        TapGestureRecognizer()..onTap = () => widget.onTap(target),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nincs hivatkozás: pontosan a korábbi egyszerű szöveg (bitre ugyanaz).
    if (_spans.isEmpty) return Text(widget.text, style: widget.style);
    final colors = Theme.of(context).colorScheme;
    final linkStyle = TextStyle(
      color: colors.primary,
      decoration: TextDecoration.underline,
      decorationColor: colors.primary,
    );
    final children = <InlineSpan>[];
    var cursor = 0;
    var index = 0;
    for (final span in _spans) {
      if (span.start > cursor) {
        children.add(TextSpan(text: widget.text.substring(cursor, span.start)));
      }
      children.add(
        TextSpan(
          text: widget.text.substring(span.start, span.end),
          style: linkStyle,
          // A felismerő azonos indexen van, mint a találat; a védelem csak
          // elméleti (ha valami mégis eltér, nem törünk el egy üzenetet).
          recognizer: index < _recognizers.length ? _recognizers[index] : null,
        ),
      );
      cursor = span.end;
      index++;
    }
    if (cursor < widget.text.length) {
      children.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return Text.rich(TextSpan(style: widget.style, children: children));
  }
}
