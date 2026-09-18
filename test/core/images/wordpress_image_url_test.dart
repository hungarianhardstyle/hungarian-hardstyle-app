import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/core/images/wordpress_image_url.dart';

const _media =
    'https://hungarianhardstyle.hu/wp-content/uploads/2026/09/image-28-1024x683.png';

void main() {
  test('a WordPress kép a kért fizikai szélességben érkezik a CDN-ről', () {
    expect(
      WordpressImageUrl.resized(_media, physicalWidth: 982),
      'https://i0.wp.com/hungarianhardstyle.hu/wp-content/uploads/2026/09/'
      'image-28-1024x683.png?w=982',
    );
  });

  test('soha nem kér nagyobbat a forrásnál (nincs felnagyítás)', () {
    // A hivatkozott változat 1024 px széles, ezért 1600 px kérésből 1024 lesz.
    expect(
      WordpressImageUrl.resized(_media, physicalWidth: 1600),
      endsWith('image-28-1024x683.png?w=1024'),
    );
    // Eredeti (méret utótag nélküli) feltöltésnél nincs felső korlát.
    expect(
      WordpressImageUrl.resized(
        'https://hungarianhardstyle.hu/wp-content/uploads/2026/09/image-28.png',
        physicalWidth: 1600,
      ),
      endsWith('image-28.png?w=1600'),
    );
  });

  test('az avatar mérete is pontosan a kért szélesség', () {
    expect(
      WordpressImageUrl.resized(_media, physicalWidth: 120),
      endsWith('image-28-1024x683.png?w=120'),
    );
  });

  test('a szélesség biztonságos határok közé esik', () {
    expect(
      WordpressImageUrl.resized(_media, physicalWidth: 4),
      endsWith('?w=48'),
    );
    expect(
      WordpressImageUrl.resized(_media, physicalWidth: 99999),
      endsWith('?w=1024'),
    );
  });

  test('a meglévő lekérdezési paraméterek megmaradnak', () {
    expect(
      WordpressImageUrl.resized(
        '$_media?huhs_badge_v=abc123',
        physicalWidth: 112,
      ),
      endsWith('?huhs_badge_v=abc123&w=112'),
    );
  });

  test('más hostokat nem érint', () {
    const untouched = [
      '',
      'https://res.cloudinary.com/fjxo93em/image/upload/v1/chat.jpg',
      'https://img.youtube.com/vi/abc/hqdefault.jpg',
      'https://lh3.googleusercontent.com/a/avatar',
      'https://example.com/wp-content/uploads/2026/09/image-1024x683.png',
    ];
    for (final url in untouched) {
      expect(
        WordpressImageUrl.resized(url, physicalWidth: 200),
        url,
        reason: url,
      );
    }
  });

  test('a már optimalizált CDN URL nem duplázódik', () {
    final once = WordpressImageUrl.resized(_media, physicalWidth: 600);
    final twice = WordpressImageUrl.resized(once, physicalWidth: 600);

    expect(twice, once);
    expect(twice, startsWith('https://i0.wp.com/hungarianhardstyle.hu/'));
    expect('i0.wp.com'.allMatches(twice).length, 1);
  });

  test('a forrás szélessége kiolvasható a fájlnévből', () {
    expect(WordpressImageUrl.derivativeWidth(_media), 1024);
    expect(
      WordpressImageUrl.derivativeWidth(
        'https://hungarianhardstyle.hu/wp-content/uploads/2026/09/image-26-1024x538.png',
      ),
      1024,
    );
    expect(
      WordpressImageUrl.derivativeWidth(
        'https://hungarianhardstyle.hu/wp-content/uploads/2026/09/image-28.png',
      ),
      0,
    );
    expect(
      WordpressImageUrl.derivativeWidth(
        'https://hungarianhardstyle.hu/wp-content/uploads/2026/09/image-28-scaled.png',
      ),
      0,
    );
  });

  test('a szolgáltatott szélesség a dekódolási méret is', () {
    // A memóriabeli dekódolás nem nagyobb, mint amit a CDN ad.
    expect(WordpressImageUrl.targetWidth(_media, physicalWidth: 1600), 1024);
    expect(WordpressImageUrl.targetWidth(_media, physicalWidth: 982), 982);
    expect(
      WordpressImageUrl.targetWidth(
        'https://res.cloudinary.com/fjxo93em/image/upload/v1/chat.jpg',
        physicalWidth: 288,
      ),
      288,
    );
  });
}
