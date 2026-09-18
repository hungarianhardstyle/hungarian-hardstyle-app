import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prize.dart';
import '../providers/prize_provider.dart';
import '../screens/prize/prize_screen.dart';
import 'home_action_card.dart';

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
class PrizeEntryCard extends ConsumerWidget {
  const PrizeEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prize = ref.watch(activePrizeProvider);
    return prize.maybeWhen(
      data: (value) =>
          value == null ? const SizedBox.shrink() : _build(context, value),
      orElse: () => const SizedBox.shrink(),
    );
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
