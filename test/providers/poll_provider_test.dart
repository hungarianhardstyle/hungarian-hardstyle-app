import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/poll.dart';
import 'package:hungarian_hardstyle_app/providers/poll_provider.dart';
import 'package:hungarian_hardstyle_app/services/poll_service.dart';

/// Szamlalo szolgaltatas: nem megy a halozatra, de rögzíti, mit kértek tőle.
class _FakePollService extends PollService {
  _FakePollService(this.poll, {this.voted = false});

  final HuhsPoll? poll;
  int calls = 0;
  bool? lastForceRefresh;

  /// A szerver valasza a „szavaztal mar?" keredesre.
  bool voted;
  int statusCalls = 0;
  int voteCalls = 0;

  @override
  Future<HuhsPoll?> activePoll({bool forceRefresh = false}) async {
    calls += 1;
    lastForceRefresh = forceRefresh;
    return poll;
  }

  @override
  Future<bool> hasVoted(int pollId) async {
    statusCalls += 1;
    return voted;
  }

  @override
  Future<bool> vote({required int pollId, required int optionIndex}) async {
    voteCalls += 1;
    final already = voted;
    voted = true;
    return already;
  }
}

const _poll = HuhsPoll(
  id: 12694,
  question: 'Tetszik az Applikació?',
  options: [
    HuhsPollOption(index: 0, label: 'Igen'),
    HuhsPollOption(index: 1, label: 'Nem'),
  ],
);

ProviderContainer _containerWith(_FakePollService fake) {
  final container = ProviderContainer(
    overrides: [pollServiceProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a nyitott kerdőívet a szolgaltatastol keri le', () async {
    final fake = _FakePollService(_poll);
    final container = _containerWith(fake);

    final value = await container.read(activePollProvider.future);

    expect(value?.id, 12694);
    expect(value?.question, 'Tetszik az Applikació?');
    expect(fake.calls, 1);
  });

  test('a lekerdezes MEGKERULI a cache-t', () async {
    // Ez a lényeg: a kerdőív megnyilasa/zarasa időponthoz kotott, ezert egy
    // mentett valasz (peldaul egy korabbi `null`) nem dönthet a kartyarol.
    final fake = _FakePollService(_poll);
    final container = _containerWith(fake);

    await container.read(activePollProvider.future);

    expect(fake.lastForceRefresh, isTrue);
  });

  test('frissites utan ujra lekerdez (nyitas/zaras követhető)', () async {
    final fake = _FakePollService(_poll);
    final container = _containerWith(fake);

    await container.read(activePollProvider.future);
    container.invalidate(activePollProvider);
    await container.read(activePollProvider.future);

    expect(fake.calls, 2);
  });

  test('zarult kerdőívnel (null) nincs megjelenitendo adat', () async {
    final fake = _FakePollService(null);
    final container = _containerWith(fake);

    expect(await container.read(activePollProvider.future), isNull);
  });

  test('a szavazott allapot a szerverrol jon, nem a widget allapotabol', () async {
    final fake = _FakePollService(_poll, voted: true);
    final container = _containerWith(fake);

    expect(await container.read(hasVotedProvider(12694).future), isTrue);
    expect(fake.statusCalls, 1);
  });

  test('ujranyitas utan a szavazott allapot UJRA lekerdezodik', () async {
    // A tulajdonos esete: a weblapon szavazott, az app viszont a regi
    // „nem szavaztal" valaszt mutatta, ezert meg egyszer engedett szavazni.
    // A valasz ezert providerben van, ami a képernyő megnyitasakor kerdez.
    final fake = _FakePollService(_poll);
    final container = _containerWith(fake);

    expect(await container.read(hasVotedProvider(12694).future), isFalse);

    // Kozben a weblapon (vagy egy korabbi munkamenetben) megszuletik a szavazat.
    fake.voted = true;
    container.invalidate(hasVotedProvider(12694));

    expect(await container.read(hasVotedProvider(12694).future), isTrue);
    expect(fake.statusCalls, 2);
  });

  test('szavazas utan a szavazott allapot frissul', () async {
    final fake = _FakePollService(_poll);
    final container = _containerWith(fake);

    expect(await container.read(hasVotedProvider(12694).future), isFalse);

    final alreadyVoted = await container
        .read(pollServiceProvider)
        .vote(pollId: 12694, optionIndex: 1);
    expect(alreadyVoted, isFalse);
    container.invalidate(hasVotedProvider(12694));

    expect(await container.read(hasVotedProvider(12694).future), isTrue);
    expect(fake.voteCalls, 1);
  });

  test('a masodik szavazas a szerver jelzeset adja vissza', () async {
    // A vegso vedelem a szerveren van (WordPress `add_post_meta(..., true)`),
    // ezert a masodik proba `alreadyVoted`-del ter vissza, nem szavaz újra.
    final fake = _FakePollService(_poll, voted: true);
    final container = _containerWith(fake);

    final alreadyVoted = await container
        .read(pollServiceProvider)
        .vote(pollId: 12694, optionIndex: 0);

    expect(alreadyVoted, isTrue);
    expect(fake.voteCalls, 1);
  });

  test('ervenytelen kerdőív-azonosito nem indit halozati kerest', () async {
    final fake = _FakePollService(_poll);
    final container = _containerWith(fake);

    expect(await container.read(hasVotedProvider(0).future), isFalse);
    expect(fake.statusCalls, 0);
  });
}
