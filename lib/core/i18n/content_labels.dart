import 'package:flutter/widgets.dart';

import 'tr.dart';

/// A **cikk kategória-sora** a MOSTANI nyelven.
///
/// **MIÉRT KELL (a tulajdonos jelzése, 2026-09-26):** *„a híreknél a kategóriák
/// is magyar"* — a kategórianevek a WordPress-ből **adatként** jönnek (magyarul),
/// és a kártyák/fejlécek eddig **nyersen** írták ki őket
/// (`post.articleCategories.join(' · ')`), ezért angol felületen is magyarul
/// látszottak. A hírek fül szűrő-chipjei **már** fordítottak
/// (`tr(context, category.name)`), a kártyák és a cikk-fejléc viszont nem.
///
/// ⚠️ A `#TBT`-hez hasonló, nyelvfüggetlen kategórianevek **változatlanul**
/// mennek át (a `tr()` ilyenkor a kulcsot adja vissza) — éles mérés: a 11 élő
/// kategóriából 10-nek van fordítása, a `#TBT` eleve angol
/// (`tmp/probe-news-categories.mjs`).
String articleCategoriesLabel(BuildContext context, List<String> categories) {
  final parts = <String>[];
  for (final category in categories) {
    final name = category.trim();
    if (name.isEmpty) continue;
    final label = tr(context, name);
    if (label.trim().isEmpty) continue;
    parts.add(label);
  }
  return parts.join(' · ');
}
