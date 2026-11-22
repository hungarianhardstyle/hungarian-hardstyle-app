import 'package:flutter/material.dart';

import '../../core/i18n/tr.dart';
import '../../core/layout/scroll_bottom_inset.dart';
import '../../services/checkin_badges_service.dart';
import '../../services/hard_wallet_plan.dart';
import '../../widgets/app_text.dart';

const _service = CheckinBadgesService();

/// Az „Ott voltam” jelvények teljes listája.
///
/// Saját jelvényeknél (`userId == null`) kiválasztható, melyik legfeljebb 3
/// látszik a főprofilon, és hogy az összes látható-e másoknak. Másnál csak
/// megnézni lehet, amit a tulajdonos megenged.
class CheckinBadgesScreen extends StatefulWidget {
  const CheckinBadgesScreen({super.key, this.userId, this.userName});

  final String? userId;
  final String? userName;

  @override
  State<CheckinBadgesScreen> createState() => _CheckinBadgesScreenState();
}

class _CheckinBadgesScreenState extends State<CheckinBadgesScreen> {
  CheckinBadgesResult? _result;
  Object? _loadError;
  final _selected = <int>[];
  bool _showAll = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final result = await _service.fetch(userId: widget.userId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _selected
          ..clear()
          ..addAll(result.featured);
        _showAll = result.showAll;
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  void _toggle(CheckinBadge badge) {
    setState(() {
      _error = null;
      if (_selected.contains(badge.eventId)) {
        _selected.remove(badge.eventId);
      } else if (_selected.length >= 3) {
        _error = 'Legfeljebb 3 jelvényt emelhetsz ki.';
      } else {
        _selected.add(badge.eventId);
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.saveFeatured(eventIds: _selected, showAll: _showAll);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'Jelvény-beállítások mentve.'))),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = hardWalletErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openBadge(CheckinBadge badge) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BadgeImage(url: badge.badgeUrl, size: 220),
            const SizedBox(height: 12),
            Text(
              badge.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (badge.title.isNotEmpty && badge.title != badge.label)
              Text(badge.title, textAlign: TextAlign.center),
            if (badge.at > 0)
              Text(
                _date(DateTime.fromMillisecondsSinceEpoch(badge.at)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const AppText('Bezárás'),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}.';

  @override
  Widget build(BuildContext context) {
    final own = widget.userId == null;
    final name = widget.userName ?? '';
    final title = own || name.isEmpty
        ? tr(context, 'Jelvényeim')
        : trArgs(context, '{name} jelvényei', {'name': name});
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: result == null
          ? Center(
              child: _loadError == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(hardWalletErrorMessage(_loadError!)),
                        TextButton(
                          onPressed: _load,
                          child: const AppText('Újrapróbálás'),
                        ),
                      ],
                    ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (result.own) ...[
                  const AppText(
                    'Válaszd ki, melyik legfeljebb 3 jelvény látszódjon a főprofilodon. '
                    'Koppints a jelvényre a nagyobb nézethez.',
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const AppText(
                      'Az összes jelvényem látható mások számára',
                    ),
                    subtitle: const AppText(
                      'Kikapcsolva mások csak a kiemelt jelvényeidet látják.',
                    ),
                    value: _showAll,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _showAll = value),
                  ),
                  const SizedBox(height: 8),
                ],
                if (result.badges.isEmpty)
                  const AppText(
                    'Még nincs jelvény: a buliban a QR-kód beolvasásával szerezhetsz.',
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final badge in result.badges)
                        _BadgeTile(
                          badge: badge,
                          selectable: result.own,
                          selected: _selected.contains(badge.eventId),
                          onOpen: () => _openBadge(badge),
                          onToggle: () => _toggle(badge),
                        ),
                    ],
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    tr(context, _error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (result.own && result.badges.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const AppText('Mentés'),
                  ),
                ],
                const ScrollBottomInset(),
              ],
            ),
    );
  }
}

class _BadgeImage extends StatelessWidget {
  const _BadgeImage({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      Icons.verified,
      size: size * 0.85,
      color: Theme.of(context).colorScheme.primary,
    );
    if (url.isEmpty) return SizedBox.square(dimension: size, child: fallback);
    return Image.network(
      url,
      width: size,
      height: size,
      errorBuilder: (_, _, _) =>
          SizedBox.square(dimension: size, child: fallback),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.badge,
    required this.selectable,
    required this.selected,
    required this.onOpen,
    required this.onToggle,
  });

  final CheckinBadge badge;
  final bool selectable;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 104,
      child: Column(
        children: [
          Stack(
            children: [
              InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: _BadgeImage(url: badge.badgeUrl, size: 88),
                ),
              ),
              if (selectable)
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    tooltip: tr(
                      context,
                      selected
                          ? 'Kiemelés megszüntetése'
                          : 'Kiemelés a főprofilon',
                    ),
                    onPressed: onToggle,
                    icon: Icon(
                      selected ? Icons.star : Icons.star_border,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            badge.label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
