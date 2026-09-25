import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/tr.dart';
import '../models/poll.dart';
import '../providers/poll_provider.dart';
import '../screens/poll/poll_screen.dart';
import 'home_action_card.dart';
import 'home_row_state.dart';

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
///
/// Amig viszont a valasz **uton van**, a sor nem tunik el: a helyen egy
/// skeleton ([HomeActionCardPlaceholder]) all, ezert a főoldal nem ugrik egyet,
/// amikor a kártya megérkezik (a WordPress valaszideje mérve 0,4–2,0 s).
class PollEntryButton extends ConsumerWidget {
  const PollEntryButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poll = ref.watch(activePollProvider);
    final value = poll.valueOrNull;
    // A döntés szándékosan tiszta függvényben van (`homeRowView`): így
    // hálózat nélkül mérhető, és a két főoldali sor nem tud eltérni egymástól.
    final view = homeRowView(
      hasValue: poll.hasValue,
      hasContent: value != null,
      isLoading: poll.isLoading,
    );
    return switch (view) {
      HomeRowView.content => _build(context, value!),
      HomeRowView.loading => const HomeActionCardPlaceholder(
        icon: Icons.poll_outlined,
      ),
      HomeRowView.empty => const SizedBox.shrink(),
    };
  }

  Widget _build(BuildContext context, HuhsPoll poll) {
    return HomeActionCard(
      key: const Key('poll-entry'),
      eyebrow: tr(context, 'KÉRDŐÍV'),
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
