import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr.dart';
import '../../models/prize.dart';
import '../../providers/community_provider.dart';
import '../../widgets/app_text.dart';
import '../community/prize_admin_screen.dart';
import '../../providers/prize_provider.dart';
import '../../services/vote_memory.dart';
import '../../widgets/brand_loading_indicator.dart';
import '../../widgets/content_refresh_icon.dart';
import '../../widgets/prize_reward_details.dart';

/// Nyeremenyjatek — a kviz sajat képernyője.
///
/// A jatekszabaly (tulajdonosi döntes):
///  * **csak a helyes valasz** nyer;
///  * egy fiok **egyszer** jatszik — ha ront, „ennyi volt", nincs javitas es
///    nincs ujraproba. Ezt a szerver zarja le, a felulet csak kijelzi;
///  * a helyes valaszt az app **soha** nem latja a sorsolas elott, ezert a
///    valaszlehetosegeknel nincs semmilyen jeloles.
///
/// A „jatszottal mar?" allapot frissen kerdődik le (`prizePlayProvider`), mert
/// valtozhatott: a felhasznalo jatszhatott egy korabbi munkamenetben, vagy a
/// sorsolas az iment hirdetett nyertest.
class PrizeScreen extends ConsumerStatefulWidget {
  const PrizeScreen({super.key, required this.prize});

  final HuhsPrize prize;

  @override
  ConsumerState<PrizeScreen> createState() => _PrizeScreenState();
}

class _PrizeScreenState extends ConsumerState<PrizeScreen> {
  int? _selected;
  bool _submitting = false;

  /// A jatek sajat eredmenye a beirás utan (a szerver valasza).
  HuhsPrizePlay? _result;

  Future<void> _refreshStatus() async {
    setState(() => _result = null);
    ref.invalidate(prizePlayProvider(widget.prize.id));
    await ref
        .read(prizePlayProvider(widget.prize.id).future)
        .catchError(
          (Object _) => const HuhsPrizePlay(played: false, correct: false),
        );
  }

  Future<void> _submit(HuhsPrize prize) async {
    final selected = _selected;
    if (selected == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(prizeServiceProvider)
          .play(prizeId: prize.id, answerIndex: selected);
      // A most rogzitett jatek eredmenye (a helyesseggel egyutt) a legfrissebb
      // ismert allapot: elmentjuk, hogy a kovetkezo megnyitasnal azonnal,
      // teves ítélet nelkul latszodjon.
      await VoteMemory.markPrizePlayed(
        ref.read(currentUidProvider),
        prize.id,
        result,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _result = result;
      });
      // A most rogzitett jatek az uj allapot; a mentett valasz frissul.
      ref.invalidate(prizePlayProvider(prize.id));
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context,
                error is Exception
                    ? _readableError(error)
                    : 'A játékot most nem sikerült rögzíteni. Próbáld újra.'),
          ),
        ),
      );
    }
  }

  String _readableError(Exception error) {
    final text = error.toString();
    if (text.contains('unauthenticated') ||
        text.contains('permission-denied')) {
      return 'A játékhoz regisztrált fiók szükséges.';
    }
    if (text.contains('resource-exhausted')) {
      return 'Túl sok próbálkozás. Próbáld kicsit később.';
    }
    return 'A játékot most nem sikerült rögzíteni. Próbáld újra.';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(communityAuthProvider).valueOrNull;
    final registered = user != null && !user.isAnonymous;
    final prize = widget.prize;
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Nyereményjáték'),
        actions: prize.isOpen
            ? [ContentRefreshIcon(onRefresh: _refreshStatus)]
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (prize.isOpen)
            _buildOpen(context, prize, registered)
          else
            _buildDrawn(context, prize),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  /// A nyereményjáték **admin-nézete** (résztvevők, válaszmegoszlás, nyertes).
  ///
  /// **A tulajdonos kérése:** *„Natív HUHS adminba bekerülhetnének az új dolgok,
  /// működően (értds: az appba)"*. A nyereményjáték eddig csak a WordPress
  /// adminjában volt átlátható; ez a gomb ugyanazt nyitja meg az appban.
  ///
  /// Szándékosan **csak adminnak** látszik: a végpont a WordPress admin-jog
  /// mögött van, ezért egy sima felhasználó csak hibaüzenetet kapna.
  void _openAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PrizeAdminScreen()),
    );
  }

  Widget _buildHeader(String eyebrow, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(
          eyebrow,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildOpen(BuildContext context, HuhsPrize prize, bool registered) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(tr(context, 'NYEREMÉNYJÁTÉK'), Icons.card_giftcard_outlined),
          const SizedBox(height: 10),
          Text(
            prize.question,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          // A nyeremény részletei **a játék alatt is** látszanak (a tulajdonos
          // jelzése: „nem kerül bele a játék leírása"). Ugyanaz a widget, mint a
          // nyertes-nézetben, ezért a kettő nem tud széthúzni; üresen nem
          // rajzol semmit.
          if (prize.prizeType.isNotEmpty || prize.prizeDescription.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: PrizeRewardDetails(
                prizeType: prize.prizeType,
                prizeDescription: prize.prizeDescription,
              ),
            ),
          const SizedBox(height: 12),
          if (!registered)
            const AppText(
              'A játékhoz regisztrált fiók szükséges. Regisztrálj, vagy jelentkezz be, és utána játszhatsz.',
            )
          else
            _buildStatus(context, prize),
          // Az admin-nézet gombja: a résztvevők, a válaszmegoszlás és a nyertes
          // (ugyanaz, amit a WordPress „Nyereményjáték" oldal mutat).
          if (ref.watch(currentUserIsAdminProvider).valueOrNull == true) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('prize-admin-open'),
                onPressed: _openAdmin,
                icon: const Icon(Icons.groups_outlined, size: 20),
                label: const AppText('Résztvevők (admin)'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatus(BuildContext context, HuhsPrize prize) {
    final result = _result;
    if (result != null) return _PlayedResult(result: result);
    final request = ref.watch(prizePlayProvider(prize.id));
    return request.when(
      // A valaszlehetosegek CSAK akkor jelennek meg, ha a szerver kifejezetten
      // azt mondta, hogy ez a fiok meg nem jatszott. Amig a valasz uton van
      // (vagy hibara futott), a lista NEM latszik: egy jatszott fioknak nem
      // szabad ujra valaszlehetosegeket latnia.
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: BrandLoadingIndicator()),
      ),
      error: (_, _) => const AppText(
        'A játék állapotát most nem sikerült lekérdezni. Ellenőrizd a kapcsolatot, és próbáld újra a jobb felső frissítés ikonnal.',
      ),
      data: (play) =>
          play.played ? _PlayedResult(result: play) : _buildBallot(context, prize),
    );
  }

  Widget _buildBallot(BuildContext context, HuhsPrize prize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Plain ListTiles instead of RadioListTile: the Material radio API is
        // being migrated to RadioGroup in this Flutter version, and the quiz
        // only needs a single selection that is read back once.
        ...prize.answers.map(
          (answer) => ListTile(
            onTap: _submitting
                ? null
                : () => setState(() => _selected = answer.index),
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              _selected == answer.index
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: _selected == answer.index
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            title: Text(answer.label),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _selected == null || _submitting
                ? null
                : () => _submit(prize),
            child: Text(_submitting ? tr(context, 'Küldés…') : tr(context, 'Játszom')),
          ),
        ),
        const SizedBox(height: 6),
        const AppText(
          'Egy fiók egyszer játszhat, a válasz utólag nem módosítható. Csak a helyes válasz nyerhet.',
          style: TextStyle(fontSize: 12, color: Colors.white60),
        ),
      ],
    );
  }

  Widget _buildDrawn(BuildContext context, HuhsPrize prize) {
    final winner = prize.winner;
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('NYERTES', Icons.emoji_events_outlined),
          const SizedBox(height: 10),
          if (prize.question.isNotEmpty)
            Text(
              prize.question,
              style: const TextStyle(fontSize: 15, color: Colors.white70),
            ),
          const SizedBox(height: 8),
          Text(
            winner?.name ?? '',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (winner != null && winner.drawnAt.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Sorsolva: ${winner.drawnAt}',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ],
          if (prize.prizeType.isNotEmpty || prize.prizeDescription.isNotEmpty) ...[
            const SizedBox(height: 14),
            PrizeRewardDetails(
              prizeType: prize.prizeType,
              prizeDescription: prize.prizeDescription,
            ),
          ],
          const SizedBox(height: 12),
          const AppText(
            'Gratulálunk a nyertesnek! A részleteket e-mailben is elküldtük.',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

/// A sajat jatek eredmenye: helyes vagy nem. Rontas utan nincs ujraproba.
class _PlayedResult extends StatelessWidget {
  const _PlayedResult({required this.result});

  final HuhsPrizePlay result;

  @override
  Widget build(BuildContext context) {
    if (result.correct) {
      return const Row(
        children: [
          Icon(Icons.check_circle_outline, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: AppText(
              'Helyes válasz! Részt veszel a sorsolásban — a nyertest a játék lezárása után hirdetjük ki.',
            ),
          ),
        ],
      );
    }
    return const Row(
      children: [
        Icon(Icons.cancel_outlined, size: 20),
        SizedBox(width: 8),
        Expanded(
          child: AppText(
            'Sajnos nem ez volt a helyes válasz. Ebben a játékban már nem tudsz újra próbálkozni — a következő játéknál ott leszünk!',
          ),
        ),
      ],
    );
  }
}
