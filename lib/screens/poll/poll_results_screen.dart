import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/i18n/tr.dart';
import '../../providers/community_provider.dart';
import '../../widgets/app_text.dart';
import '../community/admin_resource_editor_screen.dart';

/// A WordPress admin-művelet, amit a kérdőív-eredmények képernyő használ.
///
/// **Azért külön provider, hogy a képernyő tesztelhető legyen Firebase nélkül:**
/// a `CommunityService` példányosítása a Firestore-t is felépíti, ezért a teszt
/// nem tudja `overrideWithValue`-val helyettesíteni. Ez a szűk szelet viszont
/// könnyen felülírható, és pontosan azt a két műveletet fedi le, amit a képernyő
/// használ (`polls`, `poll_results`).
final pollAdminRequestProvider =
    Provider<Future<dynamic> Function(String query)>((ref) {
      return (String query) => ref
          .read(communityServiceProvider)
          .wordPressAdminRequest(path: '/huhs/v1/admin?$query');
    });

/// Az admin-cache ürítése (a frissítés ikon ezt hívja).
final pollAdminCacheClearProvider = Provider<void Function()>((ref) {
  return () => ref.read(communityServiceProvider).clearAdminCache();
});

/// A kérdőív eredmény-összesítője — CSAK adminnak.
///
/// **Ez a képernyő azért született, mert a korábbi rossz volt:** a kérdőív
/// „Eredmények megtekintése" gombja a `VotingSummaryScreen`-t nyitotta meg,
/// ami az **éves szavazás** összesítőjét kéri le
/// (`/huhs/v1/admin?action=voting_summary`). Vagyis a kérdőívnél a jelöltekre
/// leadott szavazatok látszottak a kérdőív válaszai helyett.
///
/// A kettő teljesen más: az éves szavazás jelöltekre megy (Firestore-összesítés),
/// a kérdőív pedig egyetlen kérdés válaszlehetőségeire (a szavazat-meta-sorokból
/// újraszámolva). Ez a képernyő ezért a saját `poll_results` műveletet kéri.
///
/// A választóból a **régebbi kérdőívek** is visszanézhetők — ugyanaz a viselkedés,
/// mint a WordPress-oldali „Kérdőív eredményei" lapon.
class PollResultsScreen extends ConsumerStatefulWidget {
  const PollResultsScreen({super.key});

  @override
  ConsumerState<PollResultsScreen> createState() => _PollResultsScreenState();
}

/// A választóban megjelenő kérdőív.
class _PollOption {
  const _PollOption({
    required this.id,
    required this.question,
    required this.state,
    required this.votes,
  });

  final int id;
  final String question;
  final String state;
  final int votes;

  String get stateLabel => switch (state) {
    'open' => AppStrings.tr('nyitott'),
    'before' => AppStrings.tr('még nem indult'),
    _ => AppStrings.tr('lezárult'),
  };

  String get label => '$question — $stateLabel · $votes szavazat';
}

class _PollSummary {
  const _PollSummary({
    required this.id,
    required this.question,
    required this.state,
    required this.total,
    required this.options,
  });

  final int id;
  final String question;
  final String state;
  final int total;
  final List<({String label, int count, int percent})> options;

  String get stateLabel => switch (state) {
    'open' => AppStrings.tr('nyitott'),
    'before' => AppStrings.tr('még nem indult'),
    _ => AppStrings.tr('lezárult'),
  };

  static _PollSummary? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = int.tryParse('${json['id']}') ?? 0;
    if (id <= 0) return null;
    final rawOptions = json['options'];
    final options = <({String label, int count, int percent})>[];
    if (rawOptions is List) {
      for (final item in rawOptions.whereType<Map>()) {
        options.add((
          label: (item['label'] ?? '').toString(),
          count: int.tryParse('${item['count']}') ?? 0,
          percent: int.tryParse('${item['percent']}') ?? 0,
        ));
      }
    }
    return _PollSummary(
      id: id,
      question: (json['question'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      total: int.tryParse('${json['total']}') ?? 0,
      options: options,
    );
  }
}

class _PollResultsScreenState extends ConsumerState<PollResultsScreen> {
  late Future<List<_PollOption>> _pollsFuture;
  _PollOption? _selected;
  Future<_PollSummary?>? _summaryFuture;

  @override
  void initState() {
    super.initState();
    _pollsFuture = _loadPolls();
  }

  Future<List<_PollOption>> _loadPolls() async {
    final response = await ref.read(pollAdminRequestProvider)('action=polls');
    final raw = response is Map ? response['polls'] : null;
    final polls = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (item) => _PollOption(
                  id: int.tryParse('${item['id']}') ?? 0,
                  question: (item['question'] ?? '').toString(),
                  state: (item['state'] ?? '').toString(),
                  votes: int.tryParse('${item['votes']}') ?? 0,
                ),
              )
              .where((poll) => poll.id > 0)
              .toList(growable: false)
        : const <_PollOption>[];
    if (polls.isEmpty) throw StateError('Nincs elérhető kérdőív.');
    return polls;
  }

  Future<_PollSummary?> _loadSummary(_PollOption poll) async {
    final response = await ref.read(pollAdminRequestProvider)(
      'action=poll_results&pollId=${poll.id}',
    );
    if (response is! Map) throw StateError('Az összesítő válasza érvénytelen.');
    return _PollSummary.fromJson(response['poll']);
  }

  void _refresh() {
    ref.read(pollAdminCacheClearProvider)();
    setState(() {
      _selected = null;
      _summaryFuture = null;
      _pollsFuture = _loadPolls();
    });
  }

  void _select(_PollOption? poll) {
    if (poll == null || poll.id == _selected?.id) return;
    setState(() {
      _selected = poll;
      _summaryFuture = _loadSummary(poll);
    });
  }

  Future<void> _openEditor(BuildContext context) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AdminResourceEditorScreen(
          type: 'huhs_poll',
          typeLabel: tr(context, 'Kérdőív'),
        ),
      ),
    );
    if (created == true && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Kérdőív eredményei'),
        actions: [
          // ÚJ: a tulajdonos kérése — a natív adminból **létre is** lehessen hozni
          // kérdőívet, ne csak megnézni. Ugyanazt az űrlapot nyitja, mint a
          // szerkesztés (a mezőket a szerver írja le).
          IconButton(
            key: const Key('poll-create'),
            tooltip: tr(context, 'Új kérdőív'),
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: tr(context, 'Frissítés'),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<_PollOption>>(
        future: _pollsFuture,
        builder: (context, pollsSnapshot) {
          if (pollsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (pollsSnapshot.hasError) {
            return _ErrorBody(error: pollsSnapshot.error!);
          }
          final polls = pollsSnapshot.data ?? const <_PollOption>[];
          if (polls.isEmpty) {
            return const Center(child: AppText('Nincs elérhető kérdőív.'));
          }
          final selected = _selected ??= polls.first;
          _summaryFuture ??= _loadSummary(selected);
          return FutureBuilder<_PollSummary?>(
            future: _summaryFuture,
            builder: (context, summarySnapshot) {
              if (summarySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (summarySnapshot.hasError) {
                return _ErrorBody(error: summarySnapshot.error!);
              }
              return _body(context, polls, selected, summarySnapshot.data);
            },
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<_PollOption> polls,
    _PollOption selected,
    _PollSummary? summary,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<int>(
          key: const Key('poll-results-select'),
          initialValue: selected.id,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: tr(context, 'Kérdőív'),
            border: OutlineInputBorder(),
          ),
          items: [
            for (final poll in polls)
              DropdownMenuItem<int>(
                value: poll.id,
                child: Text(
                  trArgs(
                    context,
                    '{question} — {state} · {n} szavazat',
                    {
                      'question': poll.question,
                      'state': poll.stateLabel,
                      'n': '${poll.votes}',
                    },
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (id) {
            if (id == null) return;
            for (final poll in polls) {
              if (poll.id == id) {
                _select(poll);
                return;
              }
            }
          },
        ),
        const SizedBox(height: 18),
        if (summary == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: AppText('Ehhez a kérdőívhez nem érkezett adat.'),
            ),
          )
        else ...[
          Text(summary.question, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            trArgs(context, 'Állapot: {state} · összes szavazat: {n}', {
              'state': summary.stateLabel,
              'n': '${summary.total}',
            }),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (summary.options.isEmpty)
            const AppText('Nincs válaszlehetőség beállítva.')
          else
            for (final option in summary.options)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text('${option.count} szavazat · ${option.percent}%'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: option.percent / 100,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 10),
          const AppText(
            'Az eredmény a leadott szavazatokból számol újra, ezért a lezárt kérdőíveknél is pontos marad. Ez az oldal csak adminisztrátornak látszik.',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(userFacingError(error), textAlign: TextAlign.center),
      ),
    );
  }
}
