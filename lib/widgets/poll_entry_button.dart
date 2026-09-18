import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/poll.dart';
import '../providers/poll_provider.dart';
import '../screens/poll/poll_screen.dart';
import 'home_action_card.dart';

/// Kozvelemenykutatas - a kerdőív BEJARATA a főoldalon.
///
/// A főoldal eddig egy egesz kartyat szentelt a kerdőívnek, ezert a
/// valaszlehetosegek es a „Szavazok" gomb a hírfolyam elejere kerultek. Most
/// csak egy bejarat van, a szavazas pedig a sajat képernyőjén tortenik.
///
/// A megjelenest a [HomeActionCard] adja, ezert ez a sor **pontosan olyan
/// szeles es ugyanolyan, mint az éves szavazas sora** es a felette levo hero
/// kartya.
///
/// A sor magatol eltunik, ha a szerver szerint nincs nyitott kerdőív, tehat az
/// időablak dontese tovabbra is a WordPressben szuletik.
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
    return HomeActionCard(
      key: const Key('poll-entry'),
      eyebrow: 'KÉRDŐÍV',
      label: poll.question,
      icon: Icons.poll_outlined,
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => PollScreen(poll: poll)));
      },
    );
  }
}
