import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Kis képernyő (PiP) — a stream akkor is látszik, ha az app a háttérbe kerül.
///
/// A tulajdonos kérése: *„ha leteszi az appot hatterben menjen a stream
/// kiskepernyon”*.
///
/// ⚠️ **Android:** a `MainActivity` a `supportsPictureInPicture` beállítással
/// indul, és amikor a felhasználó elhagyja az appot (`onUserLeaveHint`),
/// **belép** a kis képernyőre — de csak akkor, ha a Twitch-oldal ezt kérte
/// (`setEnabled(true)`). Így a rádió vagy a böngészés közben nem ugrik be.
///
/// ⚠️ **iOS:** a beágyazott lejátszó a WebView saját PiP-jét használja
/// (`allowsPictureInPictureMediaPlayback`, amit a `webview_flutter_wkwebview`
/// alapból **be** kapcsol, ha a vezérlő inline lejátszással jön létre). Az
/// automatikus, app-elhagyásra induló belépést a
/// `webview_picture_in_picture.dart` JavaScript-hídja viszi (a WebKit saját
/// `webkitSetPresentationMode('picture-in-picture')` hívása) — ezért itt a
/// csatorna iOS-en csak **engedélyez**, a belépést a képernyő kéri.
class PictureInPicture {
  const PictureInPicture();

  static const MethodChannel channel = MethodChannel('hu_hs/pip');

  /// Kis képernyő engedélyezése/tiltása (a Twitch-oldal lép be és ki ezzel).
  Future<void> setEnabled(bool enabled) async {
    try {
      await channel.invokeMethod<void>('setEnabled', enabled);
    } catch (error) {
      debugPrint('picture-in-picture: the switch is not available: $error');
    }
  }

  /// **Azonnali** belépés kis képernyőre (a felület gombja hívja).
  ///
  /// Androidon ez a **natív** út (`enterPictureInPictureMode`), ezért akkor is
  /// működik, ha a WebView-ban nem él a JavaScript-PiP. A visszatérési érték a
  /// siker: `false` esetén a hívó a tartalék utat választhatja.
  Future<bool> enter() async {
    try {
      return await channel.invokeMethod<bool>('enter') ?? false;
    } catch (error) {
      debugPrint('picture-in-picture: entering failed: $error');
      return false;
    }
  }
}

const PictureInPicture pictureInPicture = PictureInPicture();
