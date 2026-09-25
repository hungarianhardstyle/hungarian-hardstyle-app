import 'package:flutter/material.dart';

import '../services/chat_mention_plan.dart';

/// A `@`-javaslatok **megjelenítése** a Chat beviteli mezője fölött.
///
/// MIÉRT külön widget: ez egy **buta** lista — nem kér le semmit, nem dönt
/// jogosultságról, csak kirajzolja, amit kap. Így a hálózat (és a cache) a
/// `ChatMentionSource`-ban marad, a döntés a tiszta `chat_mention_plan.dart`-ban,
/// a megjelenítés pedig itt — és ez a rész **widget-tesztben** mérhető.
///
/// A sorok a [mentionTypeLabel] szerint **csoportosítva** jelennek meg (a
/// személyek elöl — a [mentionContentTypes] sorrendje szerint), minden sor
/// `@`-os címkével, hogy a felhasználó lássa, mi kerül a szövegbe.
class ChatMentionOverlay extends StatelessWidget {
  const ChatMentionOverlay({
    super.key,
    required this.suggestions,
    required this.onSelected,
  });

  final List<MentionSuggestion> suggestions;
  final ValueChanged<MentionSuggestion> onSelected;

  /// A csoportok sorrendje: **személyek elöl**, utána a tartalom-típusok.
  static const List<String> _typeOrder = <String>[
    mentionTypeUser,
    ...mentionContentTypes,
  ];

  /// Ennyi magas lehet a lista — fölötte görgethető, hogy ne tolja el a
  /// beviteli mezőt a képernyőről.
  static const double _maxHeight = 224;

  /// Fekvő módban a beviteli sáv is alacsonyabb (és szűkebb), ezért itt kisebb
  /// a keret: így a lista akkor sem lóg ki a kártyából, ha a billentyűzet is
  /// nyitva van.
  static const double _maxHeightLandscape = 132;

  @override
  Widget build(BuildContext context) {
    // Üresen **semmit** nem rajzolunk: a beviteli mező fölött nem marad üres
    // sáv, és a Chat elrendezése bitre ugyanaz, mint hivatkozás nélkül.
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final groups = <String, List<MentionSuggestion>>{};
    for (final suggestion in suggestions) {
      groups.putIfAbsent(suggestion.type, () => <MentionSuggestion>[]).add(
        suggestion,
      );
    }
    final types = <String>[
      ..._typeOrder.where(groups.containsKey),
      ...groups.keys.where((type) => !_typeOrder.contains(type)),
    ];
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Container(
      key: const Key('chat-mention-overlay'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      constraints: BoxConstraints(
        maxHeight: landscape ? _maxHeightLandscape : _maxHeight,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          for (final type in types) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
              child: Text(
                mentionTypeLabel(type),
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .4,
                ),
              ),
            ),
            for (final suggestion in groups[type]!)
              // Material a sor fölött: így a lista akkor is koppintható, ha
              // valaki nem Material ős alá teszi — a widget-teszt is ezt teszi.
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelected(suggestion),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${suggestion.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.primary),
                        ),
                        if (suggestion.subtitle.trim().isNotEmpty)
                          Text(
                            suggestion.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
