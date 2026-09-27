import 'package:flutter/material.dart';

import '../core/i18n/tr.dart';
import '../services/birth_date.dart';
import 'app_text.dart';

/// Dátumválasztó a **születési dátumhoz**.
///
/// A választható tartomány a hívótól függ (a tulajdonos döntése, 2026-09-27):
/// * **regisztrációnál** (`registration: true`) a **jövőbeli** és a **16 évnél
///   fiatalabb** dátum sem választható — az utolsó nap `ma − 16 év`
///   ([BirthDate.lastAllowedPick]);
/// * **már regisztrált** tagnál (Chat fül sávja, profil-szerkesztő) a **valódi
///   dátum** is beírható — a fiókot semmi nem zárja ki —, ott csak a
///   **jövőbeli** dátum tiltott, a felső határ a mai nap ([BirthDate.today]).
///
/// Visszaadás: `'YYYY-MM-DD'`, vagy `null`, ha a felhasználó nem választott.
Future<String?> pickBirthDate(
  BuildContext context, {
  String? current,
  bool registration = false,
}) async {
  final first = DateTime(BirthDate.firstYear);
  final last = registration
      ? BirthDate.lastAllowedPick()
      : BirthDate.today();
  // ⚠️ A `showDatePicker` megköveteli, hogy a kezdődátum a tartományon belül
  // legyen: egy régi, a határon kívüli tárolt dátum nem boríthatja fel a
  // választót (ilyenkor a legkésőbbi engedett napot mutatjuk).
  var initial = BirthDate.parse(current) ?? DateTime(2000, 1, 1);
  if (initial.isAfter(last)) initial = last;
  if (initial.isBefore(first)) initial = first;
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    helpText: tr(context, 'Születési dátum'),
    fieldLabelText: tr(context, 'Születési dátum'),
    cancelText: tr(context, 'Mégse'),
    confirmText: tr(context, 'Rendben'),
  );
  return picked == null ? null : BirthDate.format(picked);
}

/// A születési dátum mező (regisztrációs űrlap és profil-szerkesztő is ezt
/// használja), opcionális **nyilvános megjelenítés** kapcsolóval.
class CommunityProfileBirthDateField extends StatelessWidget {
  const CommunityProfileBirthDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.visible,
    this.onVisibleChanged,
    this.showVisibility = false,
    this.errorText,
    this.registration = false,
  });

  /// A kiválasztott dátum `'YYYY-MM-DD'` alakban (vagy `null`).
  final String? value;
  final ValueChanged<String?> onChanged;

  /// A `birthDateVisible` mező (csak szerkesztőnél van jelentése).
  final bool? visible;
  final ValueChanged<bool>? onVisibleChanged;
  final bool showVisibility;

  /// Regisztrációs űrlap: itt érvényes a **16 éves** korlát a választóban.
  final bool registration;

  /// Ha a felületnek hibát kell mutatnia (pl. kötelező mező regisztrációnál).
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final date = BirthDate.parse(value);
    final label = date == null
        ? tr(context, 'Nincs megadva')
        : MaterialLocalizations.of(context).formatMediumDate(date);
    // A **már tárolt**, 16 évnél fiatalabb dátumot jelezzük (a fiókot nem
    // zárjuk ki és nem töröljük — a tulajdonos döntése).
    final underage = date != null && !BirthDate.isAtLeast(value, BirthDate.minimumAge);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          key: const ValueKey('community-profile-birth-date'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cake_outlined),
          title: const AppText('Születési dátum'),
          subtitle: Text(label),
          trailing: TextButton(
            onPressed: () async {
              final picked = await pickBirthDate(
                context,
                current: value,
                registration: registration,
              );
              if (picked != null) onChanged(picked);
            },
            child: const AppText('Dátum kiválasztása'),
          ),
        ),
        Text(
          tr(context, 'A közösségi funkciók 16 éves kortól használhatók.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (underage) ...[
          const SizedBox(height: 4),
          Text(
            tr(
              context,
              'Figyelem: a megadott dátum szerint 16 évesnél fiatalabb vagy.',
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (showVisibility)
          SwitchListTile(
            key: const ValueKey('community-profile-birth-date-visible'),
            contentPadding: EdgeInsets.zero,
            value: visible ?? false,
            onChanged: onVisibleChanged,
            title: const AppText('Látható a nyilvános profilomon'),
            subtitle: const AppText(
              'Alapból rejtve marad; csak te dönthetsz a megjelenítéséről.',
            ),
          ),
      ],
    );
  }
}

/// A **már regisztrált**, dátum nélküli felhasználó felugró kérése (Chat fül).
///
/// Bezárható („Most nem”), és a sáv utána is figyelmeztet; a „Mentés” a
/// kiválasztott `'YYYY-MM-DD'` értékkel tér vissza, a mentést a hívó végzi.
class BirthDatePromptDialog extends StatefulWidget {
  const BirthDatePromptDialog({super.key});

  @override
  State<BirthDatePromptDialog> createState() => _BirthDatePromptDialogState();
}

class _BirthDatePromptDialogState extends State<BirthDatePromptDialog> {
  String? _value;

  @override
  Widget build(BuildContext context) {
    final date = BirthDate.parse(_value);
    return AlertDialog(
      title: const AppText('Hiányzik a születési dátum'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            'A közösségi funkciók használatához add meg a születési dátumodat. '
            'Ez nem jelenik meg nyilvánosan, amíg nem engedélyezed.',
          ),
          const SizedBox(height: 8),
          Text(
            date == null
                ? tr(context, 'Nincs megadva')
                : MaterialLocalizations.of(context).formatMediumDate(date),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final picked = await pickBirthDate(context, current: _value);
                if (picked != null && mounted) setState(() => _value = picked);
              },
              icon: const Icon(Icons.calendar_month_outlined),
              label: const AppText('Dátum kiválasztása'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const AppText('Most nem'),
        ),
        FilledButton(
          onPressed: _value == null
              ? null
              : () => Navigator.of(context).pop(_value),
          child: const AppText('Mentés'),
        ),
      ],
    );
  }
}
