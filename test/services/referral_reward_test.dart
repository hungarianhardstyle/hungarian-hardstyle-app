import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/services/referral_reward.dart';

/// **Meghívó-jutalom mindkét félnek** — a kliens oldala.
///
/// MIÉRT EZ A KAPU: a jutalom összege a **szerveren** dől el
/// (`functions/referral-reward-plan.js`), a felület viszont **számot ígér** a
/// felhasználónak. Ha a kettő elcsúszik, az app olyat állít, amit a szerver nem
/// teljesít — ezért ez a teszt a szerveroldali modulból **olvassa ki** a két
/// összeget, és megköveteli az egyezést.
void main() {
  late String serverSource;

  setUpAll(() {
    serverSource = File(
      'functions/referral-reward-plan.js',
    ).readAsStringSync();
  });

  int serverConstant(String name) {
    final match = RegExp('const $name = (\\d+);').firstMatch(serverSource);
    expect(match, isNotNull, reason: 'a szerveroldali `$name` nem található');
    return int.parse(match!.group(1)!);
  }

  test('a felület ugyanazt a két összeget ígéri, mint a szerver', () {
    expect(
      referralInviterRewardPoints,
      serverConstant('INVITER_REWARD_POINTS'),
      reason: 'a meghívó jutalma nem térhet el a szerveroldalitól',
    );
    expect(
      referralInviteeRewardPoints,
      serverConstant('INVITEE_REWARD_POINTS'),
      reason: 'a meghívott jutalma nem térhet el a szerveroldalitól',
    );
    // A meghívott jutalma kisebb, mint a meghívóé (szándékos: a meghívó munkát
    // végez, a meghívott „csak" regisztrál) — de mindkettő pozitív.
    expect(referralInviteeRewardPoints, greaterThan(0));
    expect(referralInviterRewardPoints, greaterThan(referralInviteeRewardPoints));
  });

  test('a szerver MINDKÉT oldalt jóváírja (nem marad egyoldalú)', () {
    expect(
      serverSource.contains('referralRewardPlan'),
      isTrue,
      reason: 'a döntés a tiszta modulban él',
    );
    expect(
      serverSource.contains("INVITEE_REASON_PREFIX = 'referral_welcome:'"),
      isTrue,
      reason: 'a meghívott KÜLÖN forráskulcsot kap (nem keveredik a meghívóéval)',
    );
    expect(
      serverSource.contains("INVITER_REASON_PREFIX = 'referral:'"),
      isTrue,
    );
  });

  test('az Ajánlás képernyő a KÉTOLDALI jutalmat írja ki', () {
    final screen = File(
      'lib/screens/more/referral_screen.dart',
    ).readAsStringSync();
    expect(
      screen.contains(
        "'Minden meghívott barátod után {inviter} pontot kapsz, ő pedig {invitee} pontot a kezdéshez.'",
      ),
      isTrue,
      reason: 'a szöveg a szótár kulcsa (fordítható)',
    );
    expect(
      screen.contains("'inviter': '\$referralInviterRewardPoints'") &&
          screen.contains("'invitee': '\$referralInviteeRewardPoints'"),
      isTrue,
      reason: 'a felirat a közös konstansokból dolgozik (nincs beégetett szám)',
    );
  });

  test('a regisztrációnál a meghívott LÁTJA a jutalmát', () {
    final screen = File(
      'lib/screens/community/community_screen.dart',
    ).readAsStringSync();
    expect(
      screen.contains(
        "'Ha kaptál kódot egy HUHS-felhasználótól — vele {invitee} pontot kapsz a kezdéshez.'",
      ),
      isTrue,
      reason: 'az ajánlókód mező mellett ott a meghívotti jutalom',
    );
    expect(
      screen.contains("'invitee': '\$referralInviteeRewardPoints'"),
      isTrue,
    );
  });

  test('a két új felirat angolul is megvan a szótárban', () {
    final dictionary = File('assets/i18n/en.json').readAsStringSync();
    expect(
      dictionary.contains(
        'You get {inviter} points for every friend you invite, and they get {invitee} points to start.',
      ),
      isTrue,
    );
    expect(
      dictionary.contains('it gives you {invitee} points to start'),
      isTrue,
    );
  });
}
