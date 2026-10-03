import 'package:flutter/services.dart';

/// A **zárképernyő / fejhallgató / értesítés távvezérlőjének** a parancsai.
///
/// MIÉRT (a tulajdonos jelzése, 2026-10-03): *„kéne egy pause gomb is az
/// értesítési és a zártképernyős rádió vezérlőre”*.
///
/// A mérés szerint az iOS-oldalon **senki** nem hallgatta a rendszer távvezérlőjét:
///  * a `just_audio` 0.10.6 `darwin` forrásaiban **egyetlen**
///    `MPRemoteCommandCenter`/`MPNowPlayingInfoCenter` hivatkozás sincs
///    (mérve: `Get-ChildItem … | Select-String` → nincs találat);
///  * az `ios/Runner/AppDelegate.swift` eddig csak a „Most szól” panel
///    **tartalmát** írta (`MPNowPlayingInfoCenter`), kezelőt nem kötött.
///
/// Ezért a zárképernyő szünet/leállítás gombja **hatástalan** volt. A parancs
/// értelmezése és végrehajtása ezért itt, **tisztán** él: a platform csak a
/// parancs nevét küldi, a döntés (mi történjen) egy helyen van, és hálózat/plugin
/// nélkül mérhető.
enum RadioRemoteCommand {
  /// Indítás (a „lejátszás” gomb).
  play,

  /// Szünet — a hang elhallgat, a **vezérlő megmarad**.
  pause,

  /// Ugyanaz a gomb váltogat: ha szól, szünetel; ha áll, elindul.
  toggle,

  /// Teljes leállítás (a vezérlő is eltűnik).
  stop,

  /// Ismeretlen/üres parancs — ilyenkor **nem teszünk semmit**.
  unknown,
}

/// A platformtól kapott parancsnév értelmezése — **tiszta**, ezért mérhető.
///
/// Toleráns: kis/nagybetű nem számít, a felesleges szóköz sem; minden más
/// `unknown`, amire a hívó nem csinál semmit (nem tippelünk).
RadioRemoteCommand parseRadioRemoteCommand(Object? method) {
  if (method is! String) return RadioRemoteCommand.unknown;
  switch (method.trim().toLowerCase()) {
    case 'play':
      return RadioRemoteCommand.play;
    case 'pause':
      return RadioRemoteCommand.pause;
    case 'toggle':
    case 'toggleplaypause':
    case 'toggle_play_pause':
      return RadioRemoteCommand.toggle;
    case 'stop':
      return RadioRemoteCommand.stop;
    default:
      return RadioRemoteCommand.unknown;
  }
}

/// A parancs végrehajtása — **injektált** hívásokkal, ezért platform nélkül
/// mérhető (a valódi hívók a `radio_player_bar.dart`-ban élnek).
///
/// A `toggle` ág a **pillanatnyi** állapotot kérdezi (`isPlaying`), nem a
/// felületen látszó értéket: a rendszer gombja a lejátszóhoz szól, nem a
/// képernyőhöz — és a rádió a háttérben is szólhat.
Future<void> runRadioRemoteCommand(
  RadioRemoteCommand command, {
  required Future<void> Function() play,
  required Future<void> Function() pause,
  required Future<void> Function() stop,
  required Future<bool> Function() isPlaying,
}) async {
  switch (command) {
    case RadioRemoteCommand.play:
      await play();
    case RadioRemoteCommand.pause:
      await pause();
    case RadioRemoteCommand.stop:
      await stop();
    case RadioRemoteCommand.toggle:
      if (await isPlaying()) {
        await pause();
      } else {
        await play();
      }
    case RadioRemoteCommand.unknown:
      // Szándékosan nem teszünk semmit: egy ismeretlen parancsra nem tippelünk.
      break;
  }
}

/// A platform **bejövő** hívásának a neve a `hu_hs/now_playing` csatornán.
const String radioRemoteMethodName = 'remoteCommand';

/// A távvezérlő **bekötése**: a platform (iOS `MPRemoteCommandCenter`, illetve
/// bármely jövőbeli értesítés-gomb) ezen a csatornán szól az appnak.
///
/// ⚠️ A csatorna **ugyanaz**, amin a „Most szól” cím kimegy
/// (`NowPlayingReporter.appleChannel`) — egy csatorna, két irány; így nem kell
/// új csatornát regisztrálni az `AppDelegate.swift`-ben.
///
/// A visszatérés `null`: a platform a `success`-t várja, az eredmény nem
/// értelmezett.
void bindRadioRemoteChannel(
  MethodChannel channel, {
  required Future<void> Function() play,
  required Future<void> Function() pause,
  required Future<void> Function() stop,
  required Future<bool> Function() isPlaying,
  String methodName = radioRemoteMethodName,
}) {
  channel.setMethodCallHandler((call) async {
    if (call.method != methodName) return null;
    await runRadioRemoteCommand(
      parseRadioRemoteCommand(call.arguments),
      play: play,
      pause: pause,
      stop: stop,
      isPlaying: isPlaying,
    );
    return null;
  });
}
