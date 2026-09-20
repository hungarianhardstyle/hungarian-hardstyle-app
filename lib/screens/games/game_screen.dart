import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/game.dart';
import '../../core/errors/user_facing_error.dart';
import '../../providers/news_provider.dart';
import '../../services/vote_memory.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, required this.game, this.resultsOnly = false});

  final HuhsGame game;
  final bool resultsOnly;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late List<HuhsTimelineItem> _timelineItems;
  late List<int> _answers;
  AudioPlayer? _audioPlayer;
  bool _submitting = false;
  bool _checkingSubmission = true;
  bool _submitted = false;

  /// A **helyi emlékezet** szerinti állapot: eszerint már játszottál.
  ///
  /// A tulajdonos jelzése: *„kviznél lassan frissül, hogy már kitöltötte, pár
  /// másodpercig úgy jelzi mintha tudna még játszani"*. Az állapot ugyanis csak
  /// egy három lépcsős út végén derül ki (app → Cloud Function → WordPress),
  /// addig pedig **játszhatónak** látszott a kvíz. Ezért amit egyszer már
  /// beküldtél, azt a telefon megjegyzi, és a képernyő **azonnal** „már
  /// játszottál"-t mutat; a szerver válasza a háttérben érkezik, és **ő dönt**
  /// (ha azt mondja, mégsem játszottál, visszaváltunk).
  bool _playedHint = false;

  bool _loadingResults = false;
  String? _resultsError;
  List<HuhsGameResult> _results = const [];

  bool get _isTimeline => widget.game.type == 'timeline';
  bool get _isRegisteredUser {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && !user.isAnonymous;
  }

  bool get _complete => _isTimeline
      ? _timelineItems.length >= 2
      : _answers.every((answer) => answer >= 0);

  @override
  void initState() {
    super.initState();
    _timelineItems = [...widget.game.timelineItems]..shuffle(Random());
    _answers = List<int>.filled(widget.game.questions.length, -1);
    if (widget.resultsOnly) {
      _loadResults();
    } else {
      _loadSubmissionStatus();
    }
  }

  Future<void> _loadResults() async {
    setState(() {
      _loadingResults = true;
      _resultsError = null;
    });
    try {
      final results = await ref
          .read(wordpressServiceProvider)
          .getGameResults(widget.game.id);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) {
        setState(
          () => _resultsError = 'Az eredménylista most nem tölthető be.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingResults = false);
    }
  }

  Future<void> _loadSubmissionStatus() async {
    await FirebaseAuth.instance.authStateChanges().first;
    if (!_isRegisteredUser) {
      if (mounted) setState(() => _checkingSubmission = false);
      return;
    }
    // 1. A HELYI EMLÉKEZET előbb: ha eszerint már játszottál, a képernyő
    //    azonnal ezt mutatja (nem látszik játszhatónak a kvíz a szerver
    //    válaszáig). A szerver ezután megerősíti vagy törli.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final remembered = await VoteMemory.isGamePlayed(uid, widget.game.id);
    if (!mounted) return;
    if (remembered) setState(() => _playedHint = true);
    try {
      final status = await ref
          .read(wordpressServiceProvider)
          .getGameAttemptStatus(widget.game.id);
      if (!mounted) return;
      final submitted = status['submitted'] == true;
      // A SZERVER a hiteles forrás: ha szerinte nem játszottál (pl. az admin
      // újranyitotta a kvízt), a helyi jelzést töröljük és visszaváltunk.
      if (submitted) {
        unawaited(VoteMemory.markGamePlayed(uid, widget.game.id));
      } else if (remembered) {
        unawaited(VoteMemory.clearGamePlayed(uid, widget.game.id));
      }
      setState(() {
        _submitted = submitted;
        _playedHint = submitted;
        _restoreSavedAttempt(status);
        _checkingSubmission = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checkingSubmission = false);
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    try {
      final url = await ref
          .read(wordpressServiceProvider)
          .getGameAudioClipUrl(widget.game.id);
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.setUrl(url);
      await _audioPlayer!.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A hangrészlet most nem tölthető be.')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_complete || _submitting || _submitted || _checkingSubmission) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(wordpressServiceProvider)
          .submitGameAttempt(
            gameId: widget.game.id,
            answers: _isTimeline ? null : _answers,
            orderedIds: _isTimeline
                ? _timelineItems.map((item) => item.id).toList()
                : null,
          );
      if (!mounted) return;
      // A beküldés tényét a telefon is megjegyzi: a következő megnyitáskor
      // **azonnal** „már játszottál" látszik, nem kell a szerverre várni.
      unawaited(VoteMemory.markGamePlayed(
        FirebaseAuth.instance.currentUser?.uid,
        widget.game.id,
      ));
      setState(() {
        _submitted = true;
        _playedHint = true;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _restoreSavedAttempt(Map<String, dynamic> status) {
    final savedAnswers = status['answers'];
    if (savedAnswers is List && savedAnswers.length == _answers.length) {
      final parsed = savedAnswers
          .map((value) => value is num ? value.toInt() : -1)
          .toList();
      final valid = parsed.asMap().entries.every(
        (entry) =>
            entry.value >= 0 &&
            entry.value < widget.game.questions[entry.key].options.length,
      );
      if (valid) _answers = parsed;
    }

    final savedOrderedIds = status['orderedIds'];
    if (savedOrderedIds is List && _isTimeline) {
      final ids = savedOrderedIds.map((value) => value.toString()).toList();
      final itemsById = {for (final item in _timelineItems) item.id: item};
      if (ids.length == _timelineItems.length &&
          ids.toSet().length == ids.length &&
          ids.every(itemsById.containsKey)) {
        _timelineItems = ids.map((id) => itemsById[id]!).toList();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.resultsOnly ? 'Játék eredményei' : game.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          _GameHero(game: game),
          if (widget.resultsOnly) ...[
            const SizedBox(height: 16),
            _buildResultsLeaderboard(context),
          ] else if (!_isRegisteredUser) ...[
            const SizedBox(height: 16),
            _buildRegistrationRequired(context),
          ] else ...[
            if (game.clueImageUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: game.clueImageUrl,
                  height: 180,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
            if (game.audioReady) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _submitted || _playedHint ? null : _playAudio,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Zenerészlet lejátszása'),
              ),
            ],
            const SizedBox(height: 16),
            // ⚠️ Ha a helyi emlékezet szerint MÁR JÁTSZOTTÁL, akkor addig sem
            // látszik játszhatónak a kvíz, amíg a szerver meg nem erősíti —
            // ezt a néhány másodperces „még játszhatok" látszatot jelezte a
            // tulajdonos. A kérdések ilyenkor nem szerkeszthetők.
            if (_playedHint && !_submitted)
              _buildWaitingForResult(context)
            else ...[
              if (_isTimeline)
                _buildTimeline(context)
              else
                _buildQuestions(context),
            ],
            const SizedBox(height: 20),
            if (_submitted) _buildResult(context),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  _complete &&
                      !_submitting &&
                      !_submitted &&
                      !_playedHint &&
                      !_checkingSubmission
                  ? _submit
                  : null,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _submitted || _playedHint
                    ? 'Már játszottál'
                    : 'Válaszok beküldése',
              ),
            ),
            if (!_complete && !_submitted && !_playedHint)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Minden kérdésre válaszolj a beküldés előtt.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Amíg a szerver megerősíti, hogy már játszottál (a helyi emlékezet szerint
  /// igen), addig ez a semleges állapot látszik — nem a játszható kvíz.
  Widget _buildWaitingForResult(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ebben a kvízben már játszottál',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Egy pillanat — betöltjük az eredményedet.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsLeaderboard(BuildContext context) {
    if (_loadingResults) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_resultsError != null) {
      return _GamePanel(
        child: Column(
          children: [
            Text(_resultsError!, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loadResults,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Újrapróbálás'),
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return const _GamePanel(
        child: Text(
          'Ehhez a játékhoz még nincs megjeleníthető eredmény.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return _GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Eredménylista', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final result in _results)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${result.rank}')),
              title: Text(result.displayName),
              trailing: Text(
                '${result.percent}% (${result.correctAnswers}/${result.totalAnswers})',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRegistrationRequired(BuildContext context) {
    return _GamePanel(
      child: Column(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 38,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            'Regisztráció szükséges',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'A játékot meg tudod nézni, de a válaszadáshoz regisztrált felhasználói fiók kell.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context) {
    return _GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rendezd időrendbe',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Tartsd hosszan az elemet, majd húzd a helyére.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _timelineItems.length,
            buildDefaultDragHandles: false,
            onReorderItem: (oldIndex, newIndex) {
              if (_submitted) return;
              setState(() {
                final item = _timelineItems.removeAt(oldIndex);
                _timelineItems.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final item = _timelineItems[index];
              return ListTile(
                key: ValueKey(item.id),
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(item.artist),
                subtitle: Text(item.trackTitle),
                trailing: ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_handle_rounded),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuestions(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < widget.game.questions.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GamePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${widget.game.questions[index].prompt}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  RadioGroup<int>(
                    groupValue: _answers[index],
                    onChanged: _submitted
                        ? (_) {}
                        : (value) {
                            if (value != null) {
                              setState(() => _answers[index] = value);
                            }
                          },
                    child: Column(
                      children: [
                        for (
                          var option = 0;
                          option < widget.game.questions[index].options.length;
                          option++
                        )
                          RadioListTile<int>(
                            value: option,
                            enabled: !_submitted,
                            title: Text(
                              widget.game.questions[index].options[option],
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    return _GamePanel(
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.greenAccent,
            size: 38,
          ),
          const SizedBox(height: 8),
          const Text('Köszönjük a játékodat!'),
          const SizedBox(height: 4),
          Text(
            'Az eredményeket a játék lezárása után láthatod${_resultsUntilLabel()}.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _resultsUntilLabel() {
    final date = DateTime.tryParse(widget.game.resultsUntil)?.toLocal();
    if (date == null) return '';
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return ' (eddig: ${date.year}. ${twoDigits(date.month)}. ${twoDigits(date.day)}. ${twoDigits(date.hour)}:${twoDigits(date.minute)})';
  }
}

class _GameHero extends StatelessWidget {
  const _GameHero({required this.game});

  final HuhsGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (game.artwork.isNotEmpty)
            Container(
              color: Colors.black,
              child: CachedNetworkImage(
                imageUrl: game.artwork,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('JÁTÉK', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(game.summary.isEmpty ? 'Próbáld ki magad!' : game.summary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GamePanel extends StatelessWidget {
  const _GamePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}
