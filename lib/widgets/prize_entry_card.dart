import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prize.dart';
import '../providers/prize_provider.dart';
import '../screens/prize/prize_screen.dart';
import 'home_action_card.dart';
import 'home_row_state.dart';

/// Nyeremenyjatek — a BEJARAT a főoldalon.
///
/// A megjelenest a [HomeActionCard] adja, ezert ez a sor **pontosan olyan
/// szeles es ugyanolyan, mint a kerdőív es az éves szavazas sora**, illetve a
/// felette levo hero kartya.
///
/// Ket allapotban latszik:
///  * **nyitott jatek** — „Nyereményjáték" felirattal, koppintasra megy a kviz;
///  * **kihirdetett nyertes** — a nyertes nevevel, koppintasra a reszletek.
///
/// A jatek elott a nyeremeny NEVE es LEIRASA szandekosan nem kerul a kartya
/// szovegere (a szerver sem adja ki): a kartya addig csak annyit mond, hogy
/// nyeremenyjatek van.
///
/// Amig a valasz **uton van**, a sor nem tunik el: a helyen egy skeleton
/// ([HomeActionCardPlaceholder]) all, ezert a főoldal nem ugrik egyet, amikor a
/// kártya megérkezik (a WordPress válaszideje mérve 0,4–2,0 s).
class PrizeEntryCard extends ConsumerWidget {
  const PrizeEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prize = ref.watch(activePrizeProvider);
    final value = prize.valueOrNull;
    // Ugyanaz a tiszta döntés, mint a kérdoív soránál (`homeRowView`): a két
    // főoldali sor viselkedése így nem tud elcsúszni egymástól.
    final view = homeRowView(
      hasValue: prize.hasValue,
      hasContent: value != null,
      isLoading: prize.isLoading,
    );
    return switch (view) {
      HomeRowView.content => _build(context, value!),
      HomeRowView.loading => const HomeActionCardPlaceholder(
        icon: Icons.card_giftcard_outlined,
      ),
      HomeRowView.empty => const SizedBox.shrink(),
    };
  }

  Widget _build(BuildContext context, HuhsPrize prize) {
    final winner = prize.winner;
    final drawn = !prize.isOpen && winner != null;
    return HomeActionCard(
      key: const Key('prize-entry'),
      eyebrow: drawn ? 'NYERTES' : 'NYEREMÉNYJÁTÉK',
      label: drawn
          ? (prize.question.isEmpty
                ? 'Nyertes: ${winner.name}'
                : '${prize.question} — nyertes: ${winner.name}')
          : 'Játssz és nyerj! Koppints a részvételhez',
      icon: drawn ? Icons.emoji_events_outlined : Icons.card_giftcard_outlined,
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => PrizeScreen(prize: prize)));
      },
    );
  }
}
