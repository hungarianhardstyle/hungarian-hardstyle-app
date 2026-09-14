import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/widgets/community_profile_form_fields.dart';
import 'package:hungarian_hardstyle_app/widgets/profile_access_gate.dart';

void main() {
  for (final scenario in const {
    'új Google-profil': <String, String>{'name': '', 'bio': ''},
    'új e-mailes profil': <String, String>{'name': '', 'bio': ''},
    'meglévő teljes profil': <String, String>{
      'name': 'Mentett Név',
      'bio': 'Mentett bemutatkozás',
    },
  }.entries) {
    testWidgets(
      '${scenario.key}: szerkesztés, késői profilválasz, mentés és profilkapu',
      (tester) async {
        final draft = CommunityProfileTextDraft()..bindUid('uid-a');
        addTearDown(draft.dispose);
        draft.hydrate(
          uid: 'uid-a',
          nameValue: scenario.value['name']!,
          bioValue: scenario.value['bio']!,
        );
        final profiles = StreamController<ProfileAccessState>();
        addTearDown(profiles.close);
        final server = <String, dynamic>{
          'displayName': scenario.value['name'],
          'bio': scenario.value['bio'],
          if (scenario.key == 'meglévő teljes profil') 'role': 'partygoer',
        };
        String? message;

        await tester.pumpWidget(
          MaterialApp(
            home: ProfileAccessGate(
              uid: 'uid-a',
              profile: profiles.stream,
              completion: Scaffold(
                body: ListView(
                  children: [
                    CommunityProfileFormFields(
                      draft: draft,
                      nameHelperText: 'Ez lesz a nyilvános profilneved.',
                    ),
                    FilledButton(
                      onPressed: () async {
                        try {
                          final saved = await persistCommunityProfileDraft(
                            displayName: draft.name.text,
                            claimDisplayName: (name) async {
                              server['displayName'] = name;
                            },
                            writeProfile: () async {
                              server['bio'] = draft.bio.text.trim();
                              server['role'] = 'partygoer';
                            },
                            readProfileFromServer: () async =>
                                Map<String, dynamic>.from(server),
                          );
                          draft.acceptSaved(
                            uid: 'uid-a',
                            nameValue: saved['displayName'] as String,
                            bioValue: saved['bio'] as String,
                          );
                          profiles.add(ProfileAccessState(saved));
                        } catch (error) {
                          message = error.toString();
                        }
                      },
                      child: const Text('Profil mentése'),
                    ),
                  ],
                ),
              ),
              child: const Scaffold(body: Text('Használható app')),
            ),
          ),
        );
        profiles.add(
          ProfileAccessState({
            'displayName': server['displayName'],
            // A teszt a tényleges profilbefejező űrlapot járja be; mentéskor
            // a szerveres role-visszaolvasás oldja fel a kaput.
          }),
        );
        await tester.pump();

        final nameField = find.byKey(const ValueKey('community-profile-name'));
        final bioField = find.byKey(const ValueKey('community-profile-bio'));
        await tester.tap(nameField);
        await tester.enterText(nameField, 'Törlendő név');
        tester.testTextInput.updateEditingValue(TextEditingValue.empty);
        await tester.pump();
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'Új Név',
            selection: TextSelection.collapsed(offset: 6),
            composing: TextRange(start: 0, end: 2),
          ),
        );
        await tester.pump();

        await tester.tap(bioField);
        await tester.enterText(bioField, 'Törlendő bemutatkozás');
        tester.testTextInput.updateEditingValue(TextEditingValue.empty);
        await tester.pump();
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'É',
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: 0, end: 1),
          ),
        );
        await tester.pump();

        // Ugyanazon UID Auth-frissítése és késői, régi snapshotja nem írhatja
        // vissza sem a szöveget, sem az IME composing/kijelölési állapotát.
        draft.bindUid('uid-a');
        draft.hydrate(
          uid: 'uid-a',
          nameValue: 'Késői régi név',
          bioValue: 'Késői régi bemutatkozás',
        );
        await tester.pump();
        expect(draft.name.text, 'Új Név');
        expect(draft.bio.value.text, 'É');
        expect(draft.bio.value.selection.baseOffset, 1);
        expect(draft.bio.value.composing, const TextRange(start: 0, end: 1));

        tester.testTextInput.hide();
        await tester.pump();
        await tester.tap(nameField);
        await tester.pump();
        expect(draft.name.text, 'Új Név');
        expect(draft.bio.text, 'É');

        await tester.tap(find.text('Profil mentése'));
        await tester.pump();
        await tester.pump();
        expect(message, isNull);
        expect(server['displayName'], 'Új Név');
        expect(server['bio'], 'É');
        expect(server['role'], 'partygoer');
        expect(find.text('Használható app'), findsOneWidget);
      },
    );
  }

  testWidgets('UID-váltás törli az előző felhasználó űrlapadatait', (
    tester,
  ) async {
    final draft = CommunityProfileTextDraft()..bindUid('uid-a');
    addTearDown(draft.dispose);
    draft.hydrate(uid: 'uid-a', nameValue: 'Első', bioValue: 'Első bio');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityProfileFormFields(
            draft: draft,
            nameHelperText: 'Teszt',
          ),
        ),
      ),
    );
    draft.bindUid('uid-b');
    await tester.pump();
    expect(draft.name.text, isEmpty);
    expect(draft.bio.text, isEmpty);
  });

  testWidgets('a profilbefejező mezők Navigator Overlay alatt szerkeszthetők', (
    tester,
  ) async {
    final draft = CommunityProfileTextDraft()..bindUid('uid-a');
    addTearDown(draft.dispose);
    final profiles = StreamController<ProfileAccessState>();
    addTearDown(profiles.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileAccessGate(
          uid: 'uid-a',
          profile: profiles.stream,
          completion: Scaffold(
            body: CommunityProfileFormFields(
              draft: draft,
              nameHelperText: 'Teszt',
            ),
          ),
          child: const Scaffold(body: Text('Használható app')),
        ),
      ),
    );
    profiles.add(const ProfileAccessState({'role': 'partygoer'}));
    await tester.pump();

    final nameField = find.byKey(const ValueKey('community-profile-name'));
    expect(Overlay.maybeOf(tester.element(nameField)), isNotNull);
    await tester.tap(nameField);
    await tester.enterText(nameField, 'Teszt név');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a késői első Auth UID nem írhatja felül a már szerkesztett draftot',
    (tester) async {
      final draft = CommunityProfileTextDraft();
      addTearDown(draft.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityProfileFormFields(
              draft: draft,
              nameHelperText: 'Teszt',
            ),
          ),
        ),
      );
      final nameField = find.byKey(const ValueKey('community-profile-name'));
      final bioField = find.byKey(const ValueKey('community-profile-bio'));
      await tester.enterText(nameField, 'Saját név');
      await tester.enterText(bioField, 'Új bemutatkozás');
      expect(draft.hasUnsavedEdits, isTrue);

      // A képernyő indulásakor a Firebase Auth még helyreállíthatja a
      // sessiont. A később érkező, első UID nem fiókváltás.
      draft.bindUid('uid-a');
      draft.hydrate(
        uid: 'uid-a',
        nameValue: 'Régi szervernév',
        bioValue: 'Régi szerverbemutatkozás',
      );

      expect(draft.name.text, 'Saját név');
      expect(draft.bio.text, 'Új bemutatkozás');
      draft.acceptSaved(
        uid: 'uid-a',
        nameValue: 'Saját név',
        bioValue: 'Új bemutatkozás',
      );
      expect(draft.hasUnsavedEdits, isFalse);
    },
  );

  test(
    'szerveresen nem igazolt mentés konkrét hibával újrapróbálható',
    () async {
      var claims = 0;
      await expectLater(
        persistCommunityProfileDraft(
          displayName: 'Új Név',
          claimDisplayName: (_) async => claims++,
          writeProfile: () async {},
          readProfileFromServer: () async => const {
            'displayName': '',
            'role': 'partygoer',
          },
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('profile-save-not-confirmed'),
          ),
        ),
      );
      expect(claims, 1);
    },
  );
}
