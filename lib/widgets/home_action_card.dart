import '../core/i18n/tr.dart';
import 'package:flutter/material.dart';

/// A főoldali „hero" sorok kozos megjelenese.
///
/// A tulajdonos kérése: a **Kérdőív** es az **éves szavazás** sora ugyanolyan
/// szeles legyen, mint a felette levo Hungarian Hardstyle kartya, es a
/// megjelenesuk is illjen hozza (sotet szinátmenet, piros bal oldali sav,
/// lekerekített szelek).
///
/// Ez az egyetlen hely definialja ezt a formatumot, ezert a ket sor nem tud
/// elcsúszni egymastol. A widget a főoldali `ListView` teljes belső
/// szelességet kitolti, es a jobb szelen egy nyil jelzi, hogy koppintasra
/// tovabblep.
///
/// **Flutter-korlat, amit érdemes megjegyezni:** a `Material`/`Ink` (es a
/// `BoxDecoration` kerete) csak EGYFORMA szinu kerettel tud lekerekített
/// sarkot rajzolni. Ezert a piros bal oldali sav NEM keret, hanem egy kulon
/// `Positioned` csik a `Stack`-ben — így a sarok lekerekítése es a piros sav
/// egyszerre mukodik.
class HomeActionCard extends StatelessWidget {
  const HomeActionCard({
    super.key,
    required this.eyebrow,
    required this.label,
    required this.icon,
    required this.onTap,
    this.disabled = false,
  });

  /// Kis, nagybetus felirat a szoveg felett (pl. KÉRDŐÍV).
  final String eyebrow;

  /// A sor fo szovege.
  final String label;

  /// A bal oldali ikon.
  final IconData icon;

  /// Koppintas. `null` eseten a sor nem kattinthato (pl. lezart szavazas).
  final VoidCallback? onTap;

  /// Igaz, ha a sor csak tajekoztat (nincs tovabblepes).
  final bool disabled;

  static const _radius = Radius.circular(10);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final action = disabled ? null : onTap;
    final accent = action == null ? scheme.onSurfaceVariant : scheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        button: true,
        enabled: action != null,
        label: '$eyebrow: $label',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: action,
            borderRadius: const BorderRadius.all(_radius),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surfaceContainer,
                    scheme.surfaceContainerHigh,
                  ],
                ),
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: const BorderRadius.all(_radius),
              ),
              child: Stack(
                children: [
                  // A piros bal oldali sav (a hero kartya jellegzetessege).
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: const BorderRadius.only(
                          topLeft: _radius,
                          bottomLeft: _radius,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    // A 4 px sav utan a szoveg 12-vel beljebb kezdodik:
                    // ugyanott, ahol a hero kartya tartalma.
                    padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                    child: Row(
                      children: [
                        Icon(icon, size: 22, color: accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                eyebrow,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: accent,
                                      letterSpacing: 1.4,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        if (action != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 26,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A főoldali sor **helye**, amíg a szerver válasza úton van.
///
/// **MÉRT OK:** a WordPress válaszideje 0,4–2,0 s (a válasz méretétől
/// függetlenül), és a sor eddig `SizedBox.shrink()` volt — vagyis a kártya
/// másodpercekkel később „pattant be", és a főoldal egyet ugrott. Ez a widget
/// ugyanazt a formátumot (és ugyanazokat a margókat) rajzolja, mint a valódi
/// [HomeActionCard], csak **tartalom nélkül**: két semleges sáv áll a szöveg
/// helyén, ezért nem állítunk a felhasználónak olyat, ami még nem biztos.
///
/// A sávok magassága a valódi szövegstílusokból jön (`labelSmall` +
/// `titleMedium`), ezért a betűméret-növelést is követi. A magasság a
/// **egysoros** kártyáéval egyezik meg — a kétsoros cím ettől magasabb, de
/// ilyen rövid időre nem érdemes tippelni a szöveg hosszára.
class HomeActionCardPlaceholder extends StatelessWidget {
  const HomeActionCardPlaceholder({super.key, required this.icon});

  /// Ugyanaz az ikon, mint amit a valódi sor majd mutatni fog.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        label: tr(context, 'Betöltés'),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.surfaceContainer, scheme.surfaceContainerHigh],
            ),
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: const BorderRadius.all(HomeActionCard._radius),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: const BorderRadius.only(
                      topLeft: HomeActionCard._radius,
                      bottomLeft: HomeActionCard._radius,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Row(
                  children: [
                    Icon(icon, size: 22, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SkeletonLine(
                            style: theme.textTheme.labelSmall,
                            widthFactor: 0.3,
                          ),
                          const SizedBox(height: 3),
                          _SkeletonLine(
                            style: theme.textTheme.titleMedium,
                            widthFactor: 0.72,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Egy sor magasságú semleges sáv (a szöveg helyén).
class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.style, required this.widthFactor});

  final TextStyle? style;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final fontSize = style?.fontSize ?? 14;
    final lineHeight = fontSize * (style?.height ?? 1.2);
    return SizedBox(
      height: lineHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: widthFactor,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
