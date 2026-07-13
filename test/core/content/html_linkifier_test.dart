import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/content/html_linkifier.dart';

void main() {
  test('kattinthatóvá teszi a sima szöveges URL-t', () {
    final result = linkifyPlainUrls(
      '<p>Letöltés: https://siderunnersmusic.com/#free-tracks</p>',
    );

    expect(
      result,
      contains(
        '<a href="https://siderunnersmusic.com/#free-tracks">'
        'https://siderunnersmusic.com/#free-tracks</a>',
      ),
    );
  });

  test('nem készít linket a meglévő linken belül', () {
    const html = '<a href="https://example.com">https://example.com</a>';

    expect(linkifyPlainUrls(html), html);
  });

  test('a mondatvégi írásjel nem kerül a linkbe', () {
    final result = linkifyPlainUrls('<p>Nézd meg: https://example.com.</p>');

    expect(result, contains('href="https://example.com"'));
    expect(result, contains('</a>.</p>'));
  });

  test('nem módosítja a HTML attribútumok URL-jeit', () {
    const html = '<img src="https://example.com/image.jpg">';

    expect(linkifyPlainUrls(html), html);
  });

  test('a teljes látható URL-t használja relatív fragment helyett', () {
    final target = resolveHtmlLinkTarget(
      callbackUrl: '#free-tracks',
      attributes: const {'href': '#free-tracks'},
      visibleText: 'https://siderunnersmusic.com/#free-tracks',
    );

    expect(target, 'https://siderunnersmusic.com/#free-tracks');
  });

  test('üres href esetén a callback abszolút URL-jét használja', () {
    final target = resolveHtmlLinkTarget(
      callbackUrl: 'https://example.com/page',
      attributes: const {'href': ''},
    );

    expect(target, 'https://example.com/page');
  });
}
