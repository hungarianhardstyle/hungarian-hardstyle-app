import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../providers/community_provider.dart';
import 'admin_resource_editor_screen.dart';

/// A nyereményjáték-admin WordPress admin-műveletei.
///
/// **Azért külön provider, hogy a képernyő tesztelhető legyen Firebase nélkül:**
/// a `CommunityService` példányosítása a Firestore-t is felépíti, ezért a teszt
/// nem tudja `overrideWithValue`-val helyettesíteni. Ez a szűk szelet viszont
/// felülírható, és pontosan azt a két műveletet fedi le, amit a képernyő használ
/// (`prize_games`, `prize_results`).
final prizeAdminRequestProvider =
    Provider<Future<dynamic> Function(String query)>((ref) {
      return (String query) => ref
          .read(communityServiceProvider)
          .wordPressAdminRequest(path: '/huhs/v1/admin?$query');
    });

/// Az admin-cache ürítése (a frissítés ikon ezt hívja).
final prizeAdminCacheClearProvider = Provider<void Function()>((ref) {
  return () => ref.read(communityServiceProvider).clearAdminCache();
});

/// A nyereményjáték admin-nézete — **natív, az appban**.
///
/// **A tulajdonos kérése:** *„Natív HUHS adminba bekerülhetnének az új dolgok,
/// működően (értds: az appba)"*. A nyereményjáték eddig **csak** a WordPress
/// adminjában volt átlátható (legördülő, válaszlehetőségek, résztvevők), az
/// appban nem. Ez a képernyő ugyanazt mutatja a `prize_games` és `prize_results`
/// admin-műveletekből:
///
///  * a játék állapota és a nyeremény (a sorsolás után),
///  * válaszonként hány szavazat (a **helyes válasz megjelölésével** — ezt a
///    nyilvános végpont szándékosan nem adja ki, itt admin vagyunk),
///  * résztvevők: név, választott válasz, helyes-e, mikor, és a nyertes 🏆-tal.
///
/// A nyertes bejelölése és a **megjelenítési napok** is látszanak, mert ezeket a
/// WordPress adminban állítja a tulajdonos — itt legalább ellenőrizni tudja.
class PrizeAdminScreen extends ConsumerStatefulWidget {
  const PrizeAdminScreen({super.key});

  @override
  ConsumerState<PrizeAdminScreen> createState() => _PrizeAdminScreenState();
}

/// A választóban megjelenő játék.
class _PrizeOption {
  const _PrizeOption({
    required this.id,
    required this.question,
    required this.state,
    required this.players,
    required this.correct,
    required this.winner,
  });

  final int id;
  final String question;
  final String state;
  final int players;
  final int correct;
  final String winner;

  String get stateLabel => prizeStateLabel(state);

  String get label {
    final base = '$question — $stateLabel · $players játékos';
    return winner.isEmpty ? base : '$base · 🏆 $winner';
  }
}

String prizeStateLabel(String state) => switch (state) {
  'open' => 'nyitott',
  'before' => 'még nem indult',
  'closed' => 'lezárult',
  _ => 'lezárult',
};

class _PrizeParticipant {
  const _PrizeParticipant({
    required this.name,
    required this.answerLabel,
    required this.correct,
    required this.at,
    required this.winner,
  });

  final String name;
  final String answerLabel;
  final bool correct;
  final String at;
  final bool winner;

  static _PrizeParticipant? fromJson(Object? json) {
    if (json is! Map) return null;
    return _PrizeParticipant(
      name: (json['name'] ?? '').toString(),
      answerLabel: (json['answerLabel'] ?? '').toString(),
      correct: json['correct'] == true,
      at: (json['at'] ?? '').toString(),
      winner: json['winner'] == true,
    );
  }
}

class _PrizeSummary {
  const _PrizeSummary({
    required this.id,
    required this.question,
    required this.state,
    required this.prizeType,
    required this.prizeDescription,
    required this.players,
    required this.correctCount,
    required this.displayDays,
    required this.winnerName,
    required this.winnerAt,
    required this.answers,
    required this.participants,
  });

  final int id;
  final String question;
  final String state;
  final String prizeType;
  final String prizeDescription;
  final int players;
  final int correctCount;
  final int displayDays;
  final String winnerName;
  final String winnerAt;
  final List<({String label, int count, int percent, bool correct})> answers;
  final List<_PrizeParticipant> participants;

  String get stateLabel => prizeStateLabel(state);

  static _PrizeSummary? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = int.tryParse('${json['id']}') ?? 0;
    if (id <= 0) return null;
    final correctIndex = int.tryParse('${json['correctIndex']}') ?? -1;
    final answers = <({String label, int count, int percent, bool correct})>[];
    final rawAnswers = json['answers'];
    if (rawAnswers is List) {
      for (final item in rawAnswers.whereType<Map>()) {
        final index = int.tryParse('${item['index']}') ?? -1;
        answers.add((
          label: (item['label'] ?? '').toString(),
          count: int.tryParse('${item['count']}') ?? 0,
          percent: int.tryParse('${item['percent']}') ?? 0,
          correct: index == correctIndex,
        ));
      }
    }
    final participants = <_PrizeParticipant>[];
    final rawParticipants = json['participants'];
    if (rawParticipants is List) {
      for (final item in rawParticipants) {
        final parsed = _PrizeParticipant.fromJson(item);
        if (parsed != null) participants.add(parsed);
      }
    }
    final winner = json['winner'];
    return _PrizeSummary(
      id: id,
      question: (json['question'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      prizeType: (json['prizeType'] ?? '').toString(),
      prizeDescription: (json['prizeDescription'] ?? '').toString(),
      players: int.tryParse('${json['players']}') ?? 0,
      correctCount: int.tryParse('${json['correct']}') ?? 0,
      displayDays: int.tryParse('${json['displayDays']}') ?? 0,
      winnerName: winner is Map ? (winner['name'] ?? '').toString() : '',
      winnerAt: winner is Map ? (winner['drawnAt'] ?? '').toString() : '',
      answers: answers,
      participants: participants,
    );
  }
}

class _PrizeAdminScreenState extends ConsumerState<PrizeAdminScreen> {
  late Future<List<_PrizeOption>> _gamesFuture;
  _PrizeOption? _selected;
  Future<_PrizeSummary?>? _summaryFuture;

  @override
  void initState() {
    super.initState();
    _gamesFuture = _loadGames();
  }

  Future<List<_PrizeOption>> _loadGames() async {
    final response = await ref.read(prizeAdminRequestProvider)(
      'action=prize_games',
    );
    final raw = response is Map ? response['prizes'] : null;
    final games = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (item) => _PrizeOption(
                  id: int.tryParse('${item['id']}') ?? 0,
                  question: (item['question'] ?? '').toString(),
                  state: (item['state'] ?? '').toString(),
                  players: int.tryParse('${item['players']}') ?? 0,
                  correct: int.tryParse('${item['correct']}') ?? 0,
                  winner: (item['winner'] ?? '').toString(),
                ),
              )
              .where((game) => game.id > 0)
              .toList(growable: false)
        : const <_PrizeOption>[];
    if (games.isEmpty) throw StateError('Nincs elérhető nyereményjáték.');
    return games;
  }

  Future<_PrizeSummary?> _loadSummary(_PrizeOption game) async {
    final response = await ref.read(prizeAdminRequestProvider)(
      'action=prize_results&prizeId=${game.id}',
    );
    if (response is! Map) throw StateError('A válasz érvénytelen.');
    return _PrizeSummary.fromJson(response['prize']);
  }

  void _refresh() {
    ref.read(prizeAdminCacheClearProvider)();
    setState(() {
      _selected = null;
      _summaryFuture = null;
      _gamesFuture = _loadGames();
    });
  }

  void _select(_PrizeOption? game) {
    if (game == null || game.id == _selected?.id) return;
    setState(() {
      _selected = game;
      _summaryFuture = _loadSummary(game);
    });
  }

  Future<void> _openEditor(BuildContext context) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const AdminResourceEditorScreen(
          type: 'huhs_prize',
          typeLabel: 'Nyereményjáték',
        ),
      ),
    );
    if (created == true && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nyereményjáték (admin)'),
        actions: [
          // ÚJ: létrehozás a natív adminból (a tulajdonos kérése) — ugyanaz az
          // űrlap, mint a szerkesztésnél, a mezőket a szerver írja le.
          IconButton(
            key: const Key('prize-create'),
            tooltip: 'Új nyereményjáték',
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Frissítés',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<_PrizeOption>>(
        future: _gamesFuture,
        builder: (context, gamesSnapshot) {
          if (gamesSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (gamesSnapshot.hasError) {
            return _body(gamesSnapshot.error!, null);
          }
          final games = gamesSnapshot.data ?? const <_PrizeOption>[];
          if (games.isEmpty) {
            return const Center(child: Text('Nincs elérhető nyereményjáték.'));
          }
          final selected = _selected ??= games.first;
          _summaryFuture ??= _loadSummary(selected);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: DropdownButtonFormField<int>(
                  key: const Key('prize-admin-select'),
                  initialValue: selected.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Játék',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final game in games)
                      DropdownMenuItem<int>(
                        value: game.id,
                        child: Text(
                          game.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) {
                    if (id == null) return;
                    _select(games.firstWhere((game) => game.id == id));
                  },
                ),
              ),
              Expanded(
                child: FutureBuilder<_PrizeSummary?>(
                  future: _summaryFuture,
                  builder: (context, summarySnapshot) {
                    if (summarySnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (summarySnapshot.hasError) {
                      return _body(summarySnapshot.error!, null);
                    }
                    final summary = summarySnapshot.data;
                    if (summary == null) {
                      return const Center(
                        child: Text('Ehhez a játékhoz nincs megjeleníthető adat.'),
                      );
                    }
                    return _summaryBody(summary);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _body(Object error, VoidCallback? onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A nyereményjáték adatait most nem sikerült betölteni.\n${userFacingError(error)}',
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Újrapróbálom')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryBody(_PrizeSummary summary) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Card(
          child: ListTile(
            title: Text(
              summary.question,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Állapot: ${summary.stateLabel}\n'
                'Játékosok: ${summary.players} · helyes válasz: ${summary.correctCount}\n'
                'Nyertes megjelenítése: '
                '${summary.displayDays == 0 ? 'soha nem tűnik el' : '${summary.displayDays} nap'}',
              ),
            ),
          ),
        ),
        if (summary.winnerName.isNotEmpty)
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: ListTile(
              leading: const Text('🏆', style: TextStyle(fontSize: 22)),
              title: Text('Nyertes: ${summary.winnerName}'),
              subtitle: Text(
                summary.winnerAt.isEmpty
                    ? 'A sorsolás megtörtént.'
                    : 'Sorsolás: ${summary.winnerAt}',
              ),
            ),
          ),
        if (summary.prizeType.isNotEmpty || summary.prizeDescription.isNotEmpty)
          Card(
            child: ListTile(
              title: Text(
                summary.prizeType.isEmpty ? 'Nyeremény' : summary.prizeType,
              ),
              subtitle: summary.prizeDescription.isEmpty
                  ? null
                  : Text(summary.prizeDescription),
            ),
          ),
        const SizedBox(height: 6),
        const Text(
          'Válaszlehetőségek',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        for (final answer in summary.answers)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        answer.correct ? '${answer.label}  ✔ helyes' : answer.label,
                      ),
                    ),
                    Text('${answer.count} · ${answer.percent}%'),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: answer.percent / 100),
              ],
            ),
          ),
        const SizedBox(height: 14),
        Text(
          'Résztvevők (${summary.participants.length})',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        if (summary.participants.isEmpty)
          const Text('Még senki nem játszott ebben a játékban.')
        else
          for (final participant in summary.participants)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Text(
                participant.winner ? '🏆' : (participant.correct ? '✔' : '✖'),
                style: TextStyle(
                  fontSize: 16,
                  color: participant.correct || participant.winner
                      ? Colors.greenAccent
                      : Colors.white38,
                ),
              ),
              title: Text(participant.name),
              subtitle: Text(
                '${participant.answerLabel} · ${participant.at}',
              ),
            ),
      ],
    );
  }
}
