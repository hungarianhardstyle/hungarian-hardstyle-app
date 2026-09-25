import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/services/chat_mention_plan.dart';

/// A Chat-`@`hivatkozás tiszta szabályai.
///
/// A tulajdonos kérése: *„egy @xy betűvel tudjak hivatkozni a chaten cikkre,
/// djre, szervezőre, eseményre, kiadványra vagy személyre/userre … elkezdem irni
/// a betűket és dobja fel a lehetőségeket … a személyre/userre hivatkozás legyen
/// elérhető mindenkinek, többi csak admin/moderátornak … mindegyik kattintható
/// legyen és a megfelelő helyre vigyen"*.
void main() {
  MentionSuggestion user(String name, {String id = 'u'}) =>
      MentionSuggestion(type: mentionTypeUser, id: id, label: name);

  MentionSuggestion contentItem(String type, String label, {String id = '1'}) =>
      MentionSuggestion(type: type, id: id, label: label);

  group('activeMentionQuery', () {
    test('a kurzor előtti @tokent felismeri', () {
      final query = activeMentionQuery('Szia @koba', 10);
      expect(query, isNotNull);
      expect(query!.query, 'koba');
      expect(query.start, 5);
    });

    test('üres tokennél is jelez (ilyenkor a lista eleje jön)', () {
      final query = activeMentionQuery('Szia @', 6);
      expect(query, isNotNull);
      expect(query!.query, '');
    });

    test('szóköz után nem javasol (a token lezárult)', () {
      expect(activeMentionQuery('Szia @koba valami', 16), isNull);
    });

    test('e-mail-címben nem hivatkozás', () {
      expect(activeMentionQuery('info@hungarianhardstyle.hu', 25), isNull);
    });

    test('túl hosszú token nem név', () {
      final long = 'Szia @${'a' * 40}';
      expect(activeMentionQuery(long, long.length), isNull);
    });

    test('a @ után gépelt @ sem hivatkozás', () {
      expect(activeMentionQuery('@@', 2), isNull);
    });

    test('a kurzor előtti utolsó @ számít', () {
      final query = activeMentionQuery('@elso szoveg @masod', 19);
      expect(query, isNotNull);
      expect(query!.query, 'masod');
    });

    test('üres szövegben nincs találat', () {
      expect(activeMentionQuery('', 0), isNull);
    });
  });

  group('insertMention', () {
    test('a @tokent a névre cseréli, szóközzel és új kurzorral', () {
      final query = activeMentionQuery('Szia @koba', 10)!;
      final result = insertMention(
        text: 'Szia @koba',
        query: query,
        caret: 10,
        label: 'Kobakologia',
      );
      expect(result.text, 'Szia @Kobakologia ');
      expect(result.caret, result.text.length);
    });

    test('a kurzor utáni szöveg megmarad', () {
      final text = 'Szia @koba köszönöm';
      final query = activeMentionQuery(text, 10)!;
      final result = insertMention(
        text: text,
        query: query,
        caret: 10,
        label: 'Kobakologia',
      );
      expect(result.text, 'Szia @Kobakologia  köszönöm');
    });

    test('üres névnél csak a @ marad', () {
      final query = activeMentionQuery('@', 1)!;
      final result = insertMention(
        text: '@',
        query: query,
        caret: 1,
        label: '   ',
      );
      expect(result.text, '@');
    });
  });

  group('mentionSuggestions', () {
    final users = <MentionSuggestion>[
      user('Kobakologia', id: '1'),
      user('Andrew Louis Smith', id: '2'),
      user('Kis Kobak', id: '3'),
    ];
    final content = <String, List<MentionSuggestion>>{
      mentionTypeArtist: <MentionSuggestion>[
        contentItem(mentionTypeArtist, 'Koba DJ', id: '900'),
      ],
      mentionTypeEvent: <MentionSuggestion>[
        contentItem(mentionTypeEvent, 'Hard Base Classic', id: '12505'),
      ],
    };

    test('személy mindenkinek elérhető', () {
      final list = mentionSuggestions(query: 'koba', users: users);
      expect(
        list.map((item) => item.label),
        <String>['Kobakologia', 'Kis Kobak'],
        reason: 'a név elején egyező találat előrébb van, mint a tartalmazó',
      );
    });

    test('a tartalom NEM jelenik meg nem adminnak', () {
      final list = mentionSuggestions(
        query: '',
        users: users,
        content: content,
      );
      expect(list.every((item) => item.type == mentionTypeUser), isTrue);
    });

    test('adminnak a tartalom is megjelenik, a személyek után', () {
      final list = mentionSuggestions(
        query: '',
        users: <MentionSuggestion>[user('Anna', id: '1')],
        content: content,
        privileged: true,
      );
      expect(list.first.type, mentionTypeUser);
      expect(
        list.map((item) => item.type),
        containsAll(<String>[mentionTypeArtist, mentionTypeEvent]),
      );
      expect(
        list.indexWhere((item) => item.type == mentionTypeEvent),
        greaterThan(list.indexWhere((item) => item.type == mentionTypeArtist)),
        reason: 'a tartalom-típusok sorrendje kötött',
      );
    });

    test('a név elején lévő találat előrébb van', () {
      final list = mentionSuggestions(
        query: 'kob',
        users: <MentionSuggestion>[
          user('Kis Kobak', id: '3'),
          user('Kobakologia', id: '1'),
        ],
      );
      expect(list.first.label, 'Kobakologia');
    });

    test('a limit betartja a kapott korlátot', () {
      final many = List<MentionSuggestion>.generate(
        20,
        (index) => user('Tag $index', id: '$index'),
      );
      expect(mentionSuggestions(query: '', users: many, limit: 5).length, 5);
      expect(mentionSuggestions(query: '', users: many).length, 8);
    });

    test('nincs találat esetén üres lista', () {
      expect(mentionSuggestions(query: 'zzz', users: users), isEmpty);
    });

    test('a javaslatból célpont lesz (a tárolt alakhoz)', () {
      final suggestion = mentionSuggestions(query: 'koba', users: users).first;
      final target = suggestion.toTarget();
      expect(target.type, mentionTypeUser);
      expect(target.id, isNotEmpty);
      expect(target.label, suggestion.label);
    });

    // ⚠️ A tulajdonos kérése (2026-09-25): *„kéne egy @mindenki tag is, amit ha
    // beütök, kap mindenki notifyt és csak moderátor/admin használhassa"*.
    group('@mindenki (csak adminnak/moderátornak)', () {
      List<MentionSuggestion> withEveryone(
        String query, {
        bool privileged = true,
      }) => mentionSuggestions(
        query: query,
        users: users,
        content: content,
        privileged: privileged,
      );

      test('nem adminnak EGYÁLTALÁN nem jelenik meg', () {
        for (final query in <String>['', 'min', 'mindenki']) {
          final list = mentionSuggestions(query: query, users: users);
          expect(
            list.where((item) => item.type == mentionTypeEveryone),
            isEmpty,
            reason: 'a „$query" lekérdezésre sem szabad felajánlani',
          );
        }
      });

      test('üres lekérdezésnél (a @ beírásakor) NEM ajánlja fel', () {
        expect(
          withEveryone('').where((item) => item.type == mentionTypeEveryone),
          isEmpty,
          reason:
              'egy véletlen koppintás mindenkinek küldene értesítést — csak gépelésre jöjjön',
        );
        expect(
          withEveryone('   ').where((item) => item.type == mentionTypeEveryone),
          isEmpty,
        );
      });

      test('adminnak az ELSŐ találat, ha a szó elejét írja', () {
        for (final query in <String>['m', 'min', 'mindenki', 'MINDENKI']) {
          final list = withEveryone(query);
          expect(
            list.first.type,
            mentionTypeEveryone,
            reason: 'a „$query" lekérdezésre az első találat a mindenki',
          );
          expect(list.first.label, mentionEveryoneLabel);
          expect(list.first.id, mentionEveryoneId);
          expect(list.first.subtitle, isNotEmpty);
        }
      });

      test('a „mindenki" szó közepére nem ajánlja fel', () {
        expect(
          withEveryone('denki').where(
            (item) => item.type == mentionTypeEveryone,
          ),
          isEmpty,
          reason: 'a prefix-szabály szerint csak az elejéről indulva talál',
        );
      });

      test('a célpont a kanonikus azonosítót és címkét adja', () {
        final target = withEveryone('min').first.toTarget();
        expect(target.type, mentionTypeEveryone);
        expect(target.id, mentionEveryoneId);
        expect(target.label, mentionEveryoneLabel);
        expect(target.toMap(), <String, Object>{
          'type': 'everyone',
          'id': 'everyone',
          'label': 'mindenki',
        });
      });

      test('a limitbe bele kell férnie (nem töri el a listát)', () {
        final list = mentionSuggestions(
          query: 'min',
          users: users,
          content: content,
          privileged: true,
          limit: 1,
        );
        expect(list, hasLength(1));
        expect(list.first.type, mentionTypeEveryone);
      });
    });
  });

  group('ChatMentionTarget', () {
    test('a Firestore-elemeket feldolgozza, a hibásakat kihagyja', () {
      final list = ChatMentionTarget.listFrom(<Object>[
        <String, Object>{'type': 'user', 'id': 'u1', 'label': 'Anna'},
        <String, Object>{'type': 'event', 'id': '12505', 'label': 'HBC'},
        <String, Object>{'type': 'ismeretlen', 'id': 'x', 'label': 'X'},
        <String, Object>{'type': 'user', 'id': '', 'label': 'Üres id'},
        'nem-map',
      ]);
      expect(list.length, 2);
      expect(list.first.label, 'Anna');
      expect(list.last.type, mentionTypeEvent);
    });

    test('legfeljebb 10 hivatkozást vesz figyelembe', () {
      final raw = List<Map<String, Object>>.generate(
        15,
        (index) => <String, Object>{
          'type': 'user',
          'id': 'u$index',
          'label': 'Tag $index',
        },
      );
      expect(ChatMentionTarget.listFrom(raw).length, mentionMaxCount);
    });

    test('a tárolt alak a szerződés (type/id/label)', () {
      const target = ChatMentionTarget(
        type: mentionTypeArtist,
        id: '900',
        label: 'Koba DJ',
      );
      expect(target.toMap(), <String, Object>{
        'type': 'artist',
        'id': '900',
        'label': 'Koba DJ',
      });
      expect(target.isUser, isFalse);
    });
  });

  group('mentionSpans', () {
    test('a szövegbeli @nevet megtalálja', () {
      final spans = mentionSpans('Szia @Anna, nézd meg!', <ChatMentionTarget>[
        const ChatMentionTarget(type: 'user', id: 'u1', label: 'Anna'),
      ]);
      expect(spans.length, 1);
      expect(spans.first.start, 5);
      expect(spans.first.end, 10);
      expect(spans.first.target.id, 'u1');
    });

    test('a hosszabb nevet keresi előbb (nem nyeli le a rövidebb)', () {
      final spans = mentionSpans(
        'Szia @Kiss Péter!',
        <ChatMentionTarget>[
          const ChatMentionTarget(type: 'user', id: 'rovid', label: 'Kiss'),
          const ChatMentionTarget(type: 'user', id: 'hosszu', label: 'Kiss Péter'),
        ],
      );
      expect(spans.length, 1);
      expect(spans.first.target.id, 'hosszu');
    });

    test('a szövegben nem szereplő hivatkozás nem ad találatot', () {
      final spans = mentionSpans('Szia!', <ChatMentionTarget>[
        const ChatMentionTarget(type: 'user', id: 'u1', label: 'Anna'),
      ]);
      expect(spans, isEmpty);
    });

    test('több találat növekvő sorrendben', () {
      final spans = mentionSpans(
        '@Anna és @Béla',
        <ChatMentionTarget>[
          const ChatMentionTarget(type: 'user', id: 'b', label: 'Béla'),
          const ChatMentionTarget(type: 'user', id: 'a', label: 'Anna'),
        ],
      );
      expect(spans.map((span) => span.target.id), <String>['a', 'b']);
      expect(spans.first.start, lessThan(spans.last.start));
    });

    test('üres bemenetre üres találat', () {
      expect(mentionSpans('', const <ChatMentionTarget>[]), isEmpty);
      expect(
        mentionSpans('szoveg', const <ChatMentionTarget>[]),
        isEmpty,
      );
    });

    test('a @mindenki is találat (kiemelve látszik a szövegben)', () {
      final spans = mentionSpans('Sziasztok @mindenki, ma buli!', const [
        ChatMentionTarget(
          type: mentionTypeEveryone,
          id: mentionEveryoneId,
          label: mentionEveryoneLabel,
        ),
      ]);
      expect(spans, hasLength(1));
      expect(spans.first.target.type, mentionTypeEveryone);
      expect(
        'Sziasztok @mindenki, ma buli!'.substring(
          spans.first.start,
          spans.first.end,
        ),
        '@mindenki',
      );
    });

    test('a @mindenki és egy személy egyszerre is működik', () {
      final spans = mentionSpans('@mindenki és @Anna figyeljetek', const [
        ChatMentionTarget(
          type: mentionTypeEveryone,
          id: mentionEveryoneId,
          label: mentionEveryoneLabel,
        ),
        ChatMentionTarget(type: mentionTypeUser, id: 'a', label: 'Anna'),
      ]);
      expect(spans, hasLength(2));
      expect(spans.map((span) => span.target.type), <String>[
        mentionTypeEveryone,
        mentionTypeUser,
      ]);
    });
  });

  group('típus-címkék', () {
    test('minden típusnak van magyar címkéje', () {
      expect(mentionTypeLabel(mentionTypeUser), 'Személyek');
      expect(mentionTypeLabel(mentionTypeArticle), 'Cikkek');
      expect(mentionTypeLabel(mentionTypeArtist), 'DJ-k');
      expect(mentionTypeLabel(mentionTypeOrganizer), 'Szervezők');
      expect(mentionTypeLabel(mentionTypeEvent), 'Események');
      expect(mentionTypeLabel(mentionTypeRelease), 'Kiadványok');
      expect(mentionTypeLabel(mentionTypeEveryone), 'Mindenki');
    });

    test('a konstansok egyeznek a szerveroldali korlátokkal', () {
      expect(mentionMaxCount, 10);
      expect(mentionUserNotifyMax, 5);
      expect(mentionContentTypes.length, 5);
    });
  });
}
