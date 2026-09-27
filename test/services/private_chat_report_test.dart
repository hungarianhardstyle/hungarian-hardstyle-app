import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/chat_report.dart';

/// **Felhasználó jelentése privát beszélgetésből** (a tulajdonos kérése,
/// 2026-09-27).
///
/// A jelentés a **meglévő** `chat_reports` kollekcióba megy, mert a szerveroldali
/// admin-értesítés (`handleChatReportNotification`) azt figyeli, és a
/// `reporterName` + `reason` mezőket olvassa. A mezőnevek ezért **szerződés**:
/// ezt a tiszta függvényt méri a teszt, a bekötést pedig forrás-lint.
void main() {
  test('a jelentés ugyanazokat a mezőket írja, mint a chat-jelentés', () {
    final fields = privateChatReportFields(
      reporterId: 'uid-en',
      reporterName: 'Teszt Elek',
      reportedUserId: 'uid-masik',
      reportedUserName: 'Másik Fél',
      reason: 'harassment',
      conversationId: 'uid-en_uid-masik',
      lastSenderId: 'uid-masik',
      lastMessage: '  szia  ',
    );

    // A szerver ezeket olvassa / a szabály ezeket kéri.
    expect(fields['postId'], '', reason: 'privát beszélgetésnél nincs bejegyzés');
    expect(fields['reporterId'], 'uid-en');
    expect(fields['reporterName'], 'Teszt Elek');
    expect(fields['reason'], 'harassment');
    expect(fields['reportedUserId'], 'uid-masik');
    expect(fields['reportedUserName'], 'Másik Fél');
    expect(fields['reportedText'], 'szia', reason: 'a térköz vágva');
    expect(fields['status'], 'open');
    expect(fields['source'], 'private_chat');
    expect(fields['conversationId'], 'uid-en_uid-masik');
    // A `createdAt` a hívó dolga (FieldValue), ezért itt nincs.
    expect(fields.containsKey('createdAt'), isFalse);
  });

  test('az idézet CSAK a másik fél üzenete lehet', () {
    final theirs = privateChatReportFields(
      reporterId: 'uid-en',
      reporterName: 'Én',
      reportedUserId: 'uid-masik',
      reportedUserName: 'Másik',
      reason: 'spam',
      conversationId: 'c1',
      lastSenderId: 'uid-masik',
      lastMessage: 'ez az ő üzenete',
    );
    expect(theirs['reportedText'], 'ez az ő üzenete');

    final mine = privateChatReportFields(
      reporterId: 'uid-en',
      reporterName: 'Én',
      reportedUserId: 'uid-masik',
      reportedUserName: 'Másik',
      reason: 'spam',
      conversationId: 'c1',
      lastSenderId: 'uid-en',
      lastMessage: 'ezt én írtam',
    );
    expect(
      mine['reportedText'],
      '',
      reason: 'nem tulajdonítunk neki olyan szöveget, amit nem ő írt',
    );

    final unknown = privateChatReportFields(
      reporterId: 'uid-en',
      reporterName: 'Én',
      reportedUserId: 'uid-masik',
      reportedUserName: 'Másik',
      reason: 'spam',
    );
    expect(unknown['reportedText'], '');
    expect(unknown.containsKey('conversationId'), isFalse);
  });

  test('az indok kódja a négy ismert érték egyike (más bemenet: other)', () {
    expect(chatReportReasons, ['harassment', 'hate_speech', 'spam', 'other']);
    for (final code in chatReportReasons) {
      expect(normalizeChatReportReason(code), code);
      expect(normalizeChatReportReason(code.toUpperCase()), code);
    }
    expect(normalizeChatReportReason(''), 'other');
    expect(normalizeChatReportReason(null), 'other');
    expect(normalizeChatReportReason('valami-mas'), 'other');
  });

  test('a felület az indokot a szótárból fordítja (a tárolt érték kód)', () {
    expect(chatReportReasonLabel('harassment'), 'Zaklatás');
    expect(chatReportReasonLabel('hate_speech'), 'Gyűlöletbeszéd');
    expect(chatReportReasonLabel('spam'), 'Spam');
    expect(chatReportReasonLabel('other'), 'Egyéb');
    expect(
      chatReportReasonLabel('ismeretlen'),
      'Egyéb',
      reason: 'ismeretlen kód a semleges „other” címkét kapja',
    );
    expect(chatReportReasonLabel(null), 'Egyéb');
  });

  test('a szótárban az indokok és a visszajelzés is angolul megvan', () {
    final dictionary =
        jsonDecode(File('assets/i18n/en.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final key in const [
      ...['Zaklatás', 'Gyűlöletbeszéd', 'Spam', 'Egyéb'],
      'Felhasználó jelentése',
      'Válaszd ki a jelentés okát. A jelentést a moderátorok kapják meg.',
      'Jelentés elküldve. Köszönjük, hogy jelented!',
      'Felhasználó blokkolása',
      'Forrás: {source}',
      'Privát beszélgetés',
    ]) {
      expect(dictionary[key], isNotNull, reason: 'hiányzó angol kulcs: $key');
      expect('${dictionary[key]}'.trim(), isNotEmpty);
    }
  });

  test('a bekötés megvan a szolgáltatásban és a felületen (forrás-lint)', () {
    final service = File('lib/services/community_service.dart').readAsStringSync();
    final start = service.indexOf('Future<void> reportUser(');
    expect(start, greaterThan(0), reason: 'van reportUser hívás');
    final body = service.substring(start, start + 2600);
    expect(body, contains('privateChatReportFields('));
    expect(body, contains("collection('chat_reports').add("));
    expect(body, contains("'createdAt': FieldValue.serverTimestamp()"));
    expect(
      body,
      contains("throw StateError('Jelentéshez regisztráció szükséges.')"),
      reason: 'vendég nem jelenthet',
    );
    expect(
      body,
      contains("data['lastSenderId']"),
      reason: 'az idézethez az utolsó küldő is kell',
    );

    final screen = File('lib/screens/community/private_messages_screen.dart')
        .readAsStringSync();
    expect(
      screen,
      contains("              if (value == 'report') _reportUser();"),
      reason: 'a hívás a sor elején áll (a „szerepel a szövegben" nem bizonyíték)',
    );
    expect(
      screen,
      contains("value: 'report',"),
      reason: 'a menü harmadik eleme a jelentés',
    );
    expect(screen, contains("AppText('Felhasználó jelentése')"));
    expect(screen, contains('Future<void> _reportUser() async {'));
    expect(
      screen,
      contains('for (final entry in chatReportReasons)'),
      reason: 'az oklista egy helyről jön (kód + fordítható címke)',
    );
    expect(
      screen,
      contains('SnackBarAction('),
      reason: 'a visszajelzés felajánlja a blokkolást',
    );
    expect(screen, contains('onPressed: _block,'));
    final reportStart = screen.indexOf('Future<void> _reportUser() async {');
    final reportBody = screen.substring(reportStart, reportStart + 2200);
    expect(
      reportBody.indexOf('reportUser('),
      lessThan(reportBody.indexOf('SnackBarAction(')),
      reason: 'a visszajelzés a beküldés UTÁN jön',
    );
    expect(
      reportBody.contains('blockUser('),
      isFalse,
      reason: 'automatikus blokkolás nincs',
    );
  });
}
