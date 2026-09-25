import 'package:flutter/material.dart';

import '../core/i18n/app_strings.dart';

/// A [Text] angol nyelvet ismerő változata.
///
/// MIÉRT EZ (és nem mindenhol `Text(tr(context, …))`): a felirat így a
/// **konstruktorban marad konstans**, ezért a `const` widget-fák nem törnek el —
/// mérve a kódban **581** `Text(`-hely van, és ezek ~44%-a `const` előtagú
/// sorban. A fordítás a `build`-ben történik, a `Localizations`-függőség miatt
/// pedig nyelvváltáskor újrarajzolódik.
///
/// A paraméterek **teljes** [Text]-API-t lefedik; ha valahol olyan paraméter
/// kell, ami itt hiányzik, a fordító hibát jelez (nem lehet néma eltérés).
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    // `maybeLocaleOf`: feliratkozás a nyelvváltásra (és nem dob, ha nincs
    // `Localizations` a fa fölött, pl. izolált widget-tesztben).
    Localizations.maybeLocaleOf(context);
    return Text(
      AppStrings.tr(data),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
