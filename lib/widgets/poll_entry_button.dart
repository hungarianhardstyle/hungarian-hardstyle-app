import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/poll.dart';
import '../providers/poll_provider.dart';
import '../screens/poll/poll_screen.dart';

/// Kozvelemenykutatas - a kerdőív BEJARATA a főoldalon.
///
/// A főoldal eddig egy egesz kartyat szentelt a kerdőívnek, ezert a
/// valaszlehetosegek es a „Szavazok" gomb a hírfolyam elejere kerultek, es a
/// „Legfrissebb hírek" felirat alatt lógva a hírek reszenek tűntek. Mostantól
/// itt csak egy gomb van (a „Legfrissebb hírek" felirat **fölött**), a
/// szavazas pedig a sajat képernyőjén (`PollScreen`) történik.
///
/// A gomb magatol eltunik, ha a szerver szerint nincs nyitott kerdőív, tehat
/// az időablak dontese tovabbra is a WordPressben szuletik.
class PollEntryButton extends ConsumerWidget {
  const PollEntryButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poll = ref.watch(activePollProvider);
    return poll.maybeWhen(
      data: (value) =>
          value == null ? const SizedBox.shrink() : _build(context, value),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _build(BuildContext context, HuhsPoll poll) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            minimumSize: Size.zero,
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => PollScreen(poll: poll)),
            );
          },
          icon: const Icon(Icons.poll_outlined, size: 20),
          label: Text(
            'Kérdőív: ${_shortQuestion(poll.question)}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  /// A kerdes lehet hosszu; a gomb egysoros marad, ezert vagunk.
  static String _shortQuestion(String question) {
    const limit = 46;
    final text = question.trim();
    if (text.length <= limit) return text;
    return '${text.substring(0, limit).trimRight()}…';
  }
}
