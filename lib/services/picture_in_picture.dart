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
/// (`allowsPictureInPictureMediaPlayback`), ezért itt csak **engedélyezzük** —
/// a kis képernyő gombja a videó vezérlőjében jelenik meg. Az automatikus,
/// app-elhagyásra induló PiP (mint Androidon) külön natív munka
/// (`AVPictureInPictureController`), és aláírt buildet kér.
class PictureInPicture {
  const PictureInPicture();

  static const MethodChannel channel = MethodChannel('hu_hs/pip');

  /// Kis képernyő engedélyezése/tiltása (a Twitch-oldal lép be és ki ezzel).
  Future<void> setEnabled(bool enabled) async {
    try {
      await channel.invokeMethod<void>('setEnabled', enabled);
    } catch (error) {
      debugPrint('kis képernyő: a kapcsoló nem állítható: $error');
    }
  }
}

const PictureInPicture pictureInPicture = PictureInPicture();
