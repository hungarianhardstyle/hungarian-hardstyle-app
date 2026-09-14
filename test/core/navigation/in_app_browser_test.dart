import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/navigation/in_app_browser.dart';

void main() {
  test('csak teljes HTTPS URL kerülhet a beépített böngészőbe', () {
    expect(
      isSafeInAppUri(Uri.parse('https://hungarianhardstyle.hu/hirek')),
      isTrue,
    );
    expect(
      isSafeInAppUri(Uri.parse('http://hungarianhardstyle.hu/hirek')),
      isFalse,
    );
    expect(isSafeInAppUri(Uri.parse('intent://untrusted')), isFalse);
    expect(
      isSafeInAppUri(Uri.parse('mailto:info@hungarianhardstyle.hu')),
      isFalse,
    );
  });
}
