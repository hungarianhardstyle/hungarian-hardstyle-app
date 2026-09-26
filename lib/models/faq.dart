/// A GYÍK egy eleme.
///
/// ⚠️ **A válasz tisztítása MÉRT HIBA javítása (a tulajdonos jelzése,
/// 2026-09-26):** *„a help menüben bentmaradtak a formázások mint a /P stb
/// angolul"*. A mérés (éles `GET /faq?lang=…`, 33 elem):
///  * **magyar** válaszok: **0/33** tartalmaz HTML-t (sima szöveg),
///  * **angol** válaszok: **31/33** `<p>…</p>` burkolással érkezik — a gépi
///    fordítás tette bele a bekezdés-tageket, a szerver pedig szövegként adja.
///
/// Ezért a megjeleníthető szöveget **parse-kor** készítjük el: minden felület
/// (GYÍK, keresés, későbbi helyek) egységesen tiszta szöveget kap, a magyar oldal
/// pedig bájtazonos marad (ott nincs mit tisztítani).
class FaqItem {
  final int id;
  final String question;
  final String answer;
  final String category;
  final int order;

  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    required this.order,
  });

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['order'];
    return FaqItem(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      question: faqPlainText(
        (json['question'] ?? json['title'] ?? '').toString(),
      ),
      answer: faqPlainText((json['answer'] ?? json['content'] ?? '').toString()),
      category: (json['category'] ?? '').toString(),
      order: rawOrder is num
          ? rawOrder.toInt()
          : int.tryParse('$rawOrder') ?? 0,
    );
  }
}

/// A GYÍK-szöveg **megjeleníthető** változata (HTML-tagek és entitások nélkül).
///
/// A bekezdés-határok megmaradnak: a `</p>` **két** sortörés lesz, a `<br>`
/// **egy**, a többi tag kiesik. Az ismétlődő üres sorok és a sorvégi szóközök
/// összevonódnak, a szöveg levágva (a `Text` így szépen tördel).
String faqPlainText(String value) {
  var text = value
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]*>'), '');
  // A leggyakoribb HTML-entitások (a szerver `&nbsp;`-t és idézőjeleket is küld).
  text = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
  text = text
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}
