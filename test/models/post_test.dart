import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/post.dart';

void main() {
  test('custom API excerptből eltávolítja a HTML tageket', () {
    final post = Post.fromJson({
      'excerpt':
          '<p>Első <strong>hír</strong><br>folytatás &amp; részletek</p>',
    });

    expect(post.excerpt, 'Első hír folytatás & részletek');
  });

  test('standard WordPress rendered excerptből eltávolítja a HTML tageket', () {
    final post = Post.fromWordpressJson({
      'excerpt': {'rendered': '<p>Rövid <em>összefoglaló</em>.</p>'},
    });

    expect(post.excerpt, 'Rövid összefoglaló.');
  });
  test('beolvassa és kiszűri a duplikált embedeket', () {
    final post = Post.fromJson({
      'embeds': [
        {
          'type': 'youtube',
          'url': 'https://www.youtube.com/watch?v=abc123&feature=share',
        },
        {
          'type': 'youtube',
          'url': 'https://www.youtube.com/watch?v=abc123&amp;feature=share',
        },
        {
          'type': 'spotify',
          'url': 'https://open.spotify.com/track/track123?si=test',
        },
      ],
    });

    expect(post.embeds, hasLength(2));
    expect(post.embeds.map((embed) => embed.type), ['youtube', 'spotify']);
  });

  test('felismeri és eltávolítja a támogatott shortcode-ot a HTML-ből', () {
    final post = Post.fromJson({
      'content': '<p>Szavazz!</p>[ays_poll id=2]<p>Köszönjük.</p>',
    });

    expect(post.shortcodes.single.name, 'ays_poll');
    expect(post.contentForDisplay, '<p>Szavazz!</p><p>Köszönjük.</p>');
  });

  test('eltávolítja a külön megjelenített embed nyers URL blokkját', () {
    final post = Post.fromJson({
      'content': '''
        <p>Belehallgatnál a zenékbe?</p>
        <figure class="wp-block-embed">
          <div>https://open.spotify.com/playlist/example?si=test</div>
        </figure>
        <p>https://www.youtube.com/watch?v=video123</p>
        <p>További szöveg.</p>
      ''',
      'embeds': [
        {
          'type': 'spotify',
          'url': 'https://open.spotify.com/playlist/example?si=test',
        },
        {'type': 'youtube', 'url': 'https://www.youtube.com/watch?v=video123'},
      ],
    });

    expect(post.contentForDisplay, contains('Belehallgatnál'));
    expect(post.contentForDisplay, contains('További szöveg'));
    expect(post.contentForDisplay, isNot(contains('open.spotify.com')));
    expect(post.contentForDisplay, isNot(contains('youtube.com/watch')));
  });
}
