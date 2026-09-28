import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/i18n/tr.dart';
import '../services/share_links.dart';

/// **Megosztás** gomb az adatlapokhoz (hír, esemény, kiadvány, DJ-adatlap).
///
/// MIÉRT EGY HELYEN: a megosztott szöveget a `share_links.dart` állítja össze
/// (cím → kanonikus link → egy sor az appról a Play-linkkel), a gomb pedig
/// ugyanazt a feliratot és viselkedést kapja mind a négy adatlapon — így a négy
/// hely nem tud széthúzni, és egy forrás-lint is számon kéri mindet.
///
/// ⚠️ A megosztás **néma hiba** esetén sem törheti el az adatlapot (a
/// `Share.share` platform-oldali hívás, ami elutasítható vagy dobhat).
class ContentShareButton extends StatelessWidget {
  const ContentShareButton({
    super.key,
    required this.title,
    required this.id,
    this.canonicalLink,
  });

  /// A megosztott tartalom címe (a tárgy és az üzenet első sora).
  final String title;

  /// A tartalom azonosítója — ebből lesz a rövidlink, ha nincs kanonikus link.
  final int id;

  /// A kanonikus webes link, ha a végpont ad ilyet (hír, DJ); egyébként `null`.
  final String? canonicalLink;

  Future<void> _share() async {
    final message = buildContentShareMessage(
      title: title,
      id: id,
      canonicalLink: canonicalLink,
    );
    try {
      await Share.share(message, subject: shareSubject(title));
    } catch (_) {
      // Szándékos: a megosztás hibája nem hibaüzenet a felhasználónak.
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share_outlined),
      tooltip: tr(context, 'Megosztás…'),
      onPressed: _share,
    );
  }
}
