import 'package:flutter/material.dart';

import '../core/i18n/tr.dart';

/// A **nyeremény részletei** (típus + leírás) — egy helyen, két nézetben.
///
/// **A tulajdonos jelzése:** *„a nyereményjátékba nem kerül bele a játék
/// leírása"*. A mért gyökér **kettős** volt:
///  1. a WordPress a **nyitott** játéknál szándékosan üresen küldte a
///     `prize_type` / `prize_description` mezőket (csak a sorsolás után adta ki),
///  2. az app a **nyitott** nézetben **egyáltalán nem** rajzolta ki ezeket —
///     csak a nyertes-nézetben.
///
/// Ez a widget a második felét zárja le: **ugyanaz** a megjelenítés megy a
/// nyitott játékban és a nyertes mellett, ezért a kettő nem tud széthúzni.
/// Ha nincs kitöltve semmi, **nem rajzol semmit** (nincs üres elválasztó).
class PrizeRewardDetails extends StatelessWidget {
  final String prizeType;
  final String prizeDescription;

  const PrizeRewardDetails({
    super.key,
    required this.prizeType,
    required this.prizeDescription,
  });

  @override
  Widget build(BuildContext context) {
    final type = prizeType.trim();
    final description = prizeDescription.trim();
    if (type.isEmpty && description.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 12),
        if (type.isNotEmpty)
          // ⚠️ A tulajdonos képernyőképe (2026-09-26): angol módban
          // „Nyeremény: Couple entry…" jelent meg — a **címke** maradt magyar,
          // mert a `'Nyeremény: $type'` egyetlen literál volt (a szótárban a
          // `Nyeremény` kulcs külön él). Ezért a címkét a megjelenítés helyén
          // fordítjuk, az érték (a szerverről) változatlan.
          Text(
            '${tr(context, 'Nyeremény')}: $type',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        if (description.isNotEmpty) ...[
          if (type.isNotEmpty) const SizedBox(height: 6),
          Text(description),
        ],
      ],
    );
  }
}
