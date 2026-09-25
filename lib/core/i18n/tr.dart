import 'package:flutter/widgets.dart';

import 'app_strings.dart';

/// Fordítás widget-kódból: `Text(tr(context, 'Közösség'))`.
///
/// ⚠️ MIÉRT KELL A `context`: a `Localizations` függőséget regisztráljuk, ezért
/// **nyelvváltáskor a felirat újrarajzolódik**. Egy sima statikus hívásnál a már
/// felépült widget nem épülne újra, és a régi nyelv maradna a képernyőn.
/// A `maybeLocaleOf` szándékos: `Localizations` nélkül (izolált widget-teszt)
/// nem dob, csak nem iratkozik fel.
String tr(BuildContext context, String hungarian) {
  Localizations.maybeLocaleOf(context);
  return AppStrings.tr(hungarian);
}

/// Fordítás helyőrzőkkel: `trArgs(context, '{n} nap', {'n': '$n'})`.
String trArgs(BuildContext context, String hungarian, Map<String, String> values) {
  Localizations.maybeLocaleOf(context);
  return AppStrings.trArgs(hungarian, values);
}
