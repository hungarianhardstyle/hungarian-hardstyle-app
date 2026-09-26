import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../services/wordpress_service.dart';
import 'app_language.dart';
import 'app_strings.dart';

/// Nyelvváltáskor a **betöltött részlet** (cikk, esemény, kiadvány) újratöltése.
///
/// **MIÉRT KELL (a tulajdonos jelzése, 2026-09-26):** a listák már átállnak a
/// választott nyelvre, a **már megnyitott adatlap** viszont a betöltött (régi
/// nyelvű) példányt tartotta — a *feliratok* ugyan átfordultak (`tr`), a
/// **tartalom** (cím, szöveg, leírás) nem. A tulajdonos kérése: *„csináld"*.
///
/// A minta ugyanaz, mint a hírlistánál (`PaginatedNewsNotifier`): a képernyő
/// **megjegyzi, milyen nyelven** töltötte be a tartalmat, és a WordPress-jelzésre
/// (`publicContentRefreshGeneration`) **nyelvváltást** észlelve újratölti.
///
/// ⚠️ KÉT SZÁNDÉKOS SZABÁLY:
///  1. **a tartalom a betöltés alatt is látható marad** — a régi példány csak
///     akkor cserélődik, ha az új megérkezett (nincs üres villanás, és hiba
///     esetén a régi marad);
///  2. **a jelzés önmagában nem elég** (az a tartalom-frissülésnél is felhúz),
///     ezért csak **nyelvváltásra** töltünk újra — így egy háttér-frissítés nem
///     indít felesleges kérést.
mixin ContentLanguageReload<T extends StatefulWidget> on State<T> {
  AppLanguage _contentLanguage = AppStrings.language;
  bool _reloading = false;
  bool _listening = false;

  /// A képernyő saját újratöltése — a leszármazott írja meg (a meglévő
  /// `_loadFull…` útját hívja, amely hiba esetén megtartja a régit).
  Future<void> reloadForLanguage();

  @override
  void initState() {
    super.initState();
    _contentLanguage = AppStrings.language;
    WordpressService.publicContentRefreshGeneration.addListener(_onSignal);
    _listening = true;
  }

  @override
  void dispose() {
    if (_listening) {
      WordpressService.publicContentRefreshGeneration.removeListener(_onSignal);
      _listening = false;
    }
    super.dispose();
  }

  void _onSignal() {
    if (!mounted) return;
    final current = AppStrings.language;
    if (current == _contentLanguage) return;
    _contentLanguage = current;
    // Egy futó újratöltés nem indul újra; a nyelv viszont már az új értéket
    // hordozza, ezért egy következő jelzés a legfrissebb nyelvet tölti.
    if (_reloading) return;
    _reloading = true;
    unawaited(
      reloadForLanguage()
          .catchError((Object _) {})
          .whenComplete(() => _reloading = false),
    );
  }
}
