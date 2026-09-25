import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/app_language.dart';
import '../core/i18n/tr.dart';
import '../providers/language_provider.dart';

/// HU/EN kapcsoló — a felirat mindig a **másik** nyelv kódja (HU módban „EN").
///
/// A tulajdonos kérése: *„kell majd egy HU/EN kapcsoló valahova a főoldalra
/// tetejére, pl a jobb sarokba"*. A stílus a szomszédos fejléc-gombokat követi
/// (`surfaceContainerHigh` háttér, `outlineVariant` keret, 10-es lekerekítés).
class LanguageSwitchButton extends ConsumerWidget {
  const LanguageSwitchButton({super.key, this.compact = true, this.showIcon = true});

  /// Igaz: a fejlécbe való, rövid változat.
  final bool compact;

  /// A fordító-ikon látszódjon-e. Szűk készüléken (fejléc) kikapcsolva a
  /// **csak kód** („EN"/„HU") marad — mérve ez ~25 px-cel keskenyebb.
  final bool showIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final scheme = Theme.of(context).colorScheme;
    final label = appLanguageSwitchLabel(language);
    return Tooltip(
      message: '${tr(context, 'Nyelv')}: ${appLanguageName(otherLanguage(language))}',
      child: OutlinedButton(
        key: const Key('language-switch-button'),
        onPressed: () => ref.read(languageProvider.notifier).toggle(),
        style: OutlinedButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHigh,
          foregroundColor: scheme.onSurfaceVariant,
          side: BorderSide(color: scheme.outlineVariant),
          padding: compact
              ? EdgeInsets.symmetric(horizontal: showIcon ? 10 : 12)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          minimumSize: compact ? const Size(0, 40) : const Size(0, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(
                Icons.translate_rounded,
                size: compact ? 18 : 20,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
