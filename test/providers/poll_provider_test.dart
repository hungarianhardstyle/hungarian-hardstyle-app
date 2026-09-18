import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/poll.dart';
import 'package:hungarian_hardstyle_app/providers/poll_provider.dart';
import 'package:hungarian_hardstyle_app/services/poll_service.dart';

/// Szamlalo szolgaltatas: nem megy a halozatra, de rögzíti, mit kértek tőle.
class _FakePollService extends PollService {
  _FakePollService(this.poll);

  final HuhsPoll? poll;
  int calls = 0;
  bool? lastForceRefresh;

  @override
  Future<HuhsPoll?> activePoll({bool forceRefresh = false}) async {
    calls += 1;
    lastForceRefresh = forceRefresh;
    return poll;
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
}
