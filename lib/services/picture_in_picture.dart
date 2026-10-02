import 'package:flutter/material.dart';
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
  PictureInPicture();

  static const MethodChannel channel = MethodChannel('hu_hs/pip');

  /// A kis képernyő **állapota** — a natív oldal jelenti (`changed`), amikor a
  /// felhasználó be- vagy kilép.
  ///
  /// MIÉRT KELL (a tulajdonos jelzése, 2026-10-02): *„ez a kis ablak a PIP is
  /// elég FOSCSI, a rádió gomb dominál”*. A PiP-ablak az **egész felületet**
  /// mutatta (chat, támogatás gomb, rádiósáv) — így a kis ablak használhatatlan
  /// volt. Ebből az állapotból tudja a felület **csak a videót** kirajzolni.
  final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  /// A natív jelzések bekötése (egyszer, az app indulásakor hívjuk).
  void bind() {
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'changed':
          active.value = call.arguments == true;
        case 'state':
          active.value = call.arguments == true;
        default:
          return null;
      }
      return null;
    });
  }

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
  /// siker: `false` esetén a hívó **megmondja a felhasználónak**, hogy a
  /// rendszer nem engedte (ez fontos — a tulajdonos jelzése szerint a gomb
  /// „nem megy”, és eddig nem derült ki, miért).
  Future<bool> enter() async {
    try {
      return await channel.invokeMethod<bool>('enter') ?? false;
    } catch (error) {
      debugPrint('picture-in-picture: entering failed: $error');
      return false;
    }
  }
}

final PictureInPicture pictureInPicture = PictureInPicture();

/// PiP-ben **elrejti** a gyereket — a kis ablakban csak a videó látszódjon.
///
/// A tulajdonos jelzése: *„ez a kis ablak a PIP is elég FOSCSI, a rádió gomb
/// dominál”*. Ez a burok az app keretére (rádiósáv, alsó menü) kerül, ezért a
/// kis ablakban nem marad ott a többi felület.
class HiddenInPictureInPicture extends StatelessWidget {
  const HiddenInPictureInPicture({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: pictureInPicture.active,
      builder: (context, active, _) => active ? const SizedBox.shrink() : child,
    );
  }
}
