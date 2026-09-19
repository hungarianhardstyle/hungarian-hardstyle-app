import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/submission_rules.dart';

/// Ki mit küldhet be — a tulajdonos szabálya:
/// *„djt csak dj szerepkörrel, esemény csak szervező szerepkörrel és szervezőt
/// is szervező szerepkörrel lehet csak beküldeni"*.
///
/// A szerver ugyanezt kényszeríti ki (`submissionRoleAllows`), ez a teszt pedig
/// a **felület** szabályát méri: ne kínáljon olyat, amit a szerver elutasítana.
void main() {
  test('a szerepkör-tábla a döntés szerint való', () {
    expect(SubmissionRules.requiredRoles['event'], ['organizer']);
    expect(SubmissionRules.requiredRoles['artist'], ['dj']);
    expect(SubmissionRules.requiredRoles['organizer'], ['organizer']);
  });

  test('eseményt csak szervező (vagy admin) küldhet be', () {
    expect(
      SubmissionRules.canSubmit(kind: 'event', registered: true, role: 'organizer', isAdmin: false),
      isTrue,
    );
    expect(
      SubmissionRules.canSubmit(kind: 'event', registered: true, role: 'dj', isAdmin: false),
      isFalse,
      reason: 'DJ nem küldhet be eseményt (a tulajdonos döntése)',
    );
    expect(
      SubmissionRules.canSubmit(kind: 'event', registered: true, role: 'partygoer', isAdmin: false),
      isFalse,
    );
    expect(
      SubmissionRules.canSubmit(kind: 'event', registered: true, role: 'partygoer', isAdmin: true),
      isTrue,
    );
  });

  test('DJ-t csak DJ-szerepkörrel, szervezőt csak szervezővel', () {
    expect(
      SubmissionRules.canSubmit(kind: 'artist', registered: true, role: 'dj', isAdmin: false),
      isTrue,
    );
    expect(
      SubmissionRules.canSubmit(kind: 'artist', registered: true, role: 'organizer', isAdmin: false),
      isFalse,
    );
    expect(
      SubmissionRules.canSubmit(kind: 'organizer', registered: true, role: 'organizer', isAdmin: false),
      isTrue,
    );
    expect(
      SubmissionRules.canSubmit(kind: 'organizer', registered: true, role: 'dj', isAdmin: false),
      isFalse,
    );
  });

  test('vendég és ismeretlen típus nem küldhet be', () {
    expect(
      SubmissionRules.canSubmit(kind: 'event', registered: false, role: 'organizer', isAdmin: false),
      isFalse,
    );
    expect(
      SubmissionRules.canSubmit(kind: 'ismeretlen', registered: true, role: 'organizer', isAdmin: true),
      isFalse,
      reason: 'amit a szerver nem ismer, azt a felület ne is kínálja',
    );
  });

  test('a tiltás szövege megnevezi a szükséges szerepkört', () {
    expect(SubmissionRules.denialMessage('event'), contains('szervezői'));
    expect(SubmissionRules.denialMessage('artist'), contains('DJ'));
    expect(SubmissionRules.notice, contains('szervezői'));
    expect(SubmissionRules.notice, contains('DJ'));
  });
}
