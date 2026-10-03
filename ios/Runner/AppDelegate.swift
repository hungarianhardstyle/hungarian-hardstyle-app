import Flutter
import UIKit
import MediaPlayer

/// A HUHS app iOS-belépési pontja.
///
/// 2026-10-01: **„Most szól” a zárképernyőn** — a tulajdonos kérése:
/// *„kiírhatná itt is a zenét ami szól + zárképernyőn is lehessen látni a radio a
/// real hardstyle fm logóval”*.
///
/// ⚠️ MIÉRT KELL EZ IDE: a rádió iOS-en `just_audio`-val szól (nem
/// `audio_service`-szel), ezért a rendszer „Most szól” panelje
/// (`MPNowPlayingInfoCenter`) **magától semmit nem tud** a számról. A Dart-oldal
/// (`lib/services/now_playing.dart`) ugyanazt az ICY-metaadatot olvassa, amit az
/// Android is, és ide küldi a `hu_hs/now_playing` csatornán.
///
/// ⚠️ A borító a **csomagba épített** logó (`Assets.xcassets/RealHardstyleLogo`),
/// ezért nincs hálózati függőség és nincs külön letöltés.
///
/// 2026-10-03: **a zárképernyő gombjai** — a tulajdonos jelzése: *„kéne egy pause
/// gomb is az értesítési és a zártképernyős rádió vezérlőre”*. MÉRT HIÁNY: a
/// `just_audio` 0.10.6 `darwin` forrásaiban **egyetlen** `MPRemoteCommandCenter`
/// hivatkozás sincs, és eddig ez a fájl is csak a panel **tartalmát** írta —
/// ezért a zárképernyő szünet/leállítás gombja hatástalan volt. Mostantól a
/// rendszer parancsait ide kötjük be, és a Dart-oldal (`radio_player_bar.dart` →
/// `radio_remote.dart`) hajtja végre ugyanazon a rádió-életcikluson, amit a
/// felület használ.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var nowPlayingChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HuhsNowPlaying") {
      let channel = FlutterMethodChannel(
        name: "hu_hs/now_playing",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handleNowPlaying(call, result: result)
      }
      nowPlayingChannel = channel
      bindRemoteCommands()
    }
  }

  /// A zárképernyő / fejhallgató / (CarPlay) távvezérlőjének bekötése.
  ///
  /// A rendszer ezeket a parancsokat akkor küldi, ha az app a „Most szól” panel
  /// tulajdonosa — ezért a `metadata` hívás után válnak élővé.
  private func bindRemoteCommands() {
    let center = MPRemoteCommandCenter.shared()
    addRemoteTarget(center.playCommand, name: "play")
    addRemoteTarget(center.pauseCommand, name: "pause")
    addRemoteTarget(center.togglePlayPauseCommand, name: "toggle")
    addRemoteTarget(center.stopCommand, name: "stop")
  }

  /// Egy gomb bekötése: a rendszer `success`-öt vár, hogy ne jelezzen hibát.
  private func addRemoteTarget(_ command: MPRemoteCommand, name: String) {
    command.isEnabled = true
    _ = command.addTarget { [weak self] _ in
      guard let self = self else { return .commandFailed }
      self.sendRemoteCommand(name)
      return .success
    }
  }

  /// A parancs átadása a Dart-oldalnak, és a gomb állapotának azonnali váltása.
  ///
  /// ⚠️ A `playbackRate` azért kell, mert a zárképernyő ebből rajzolja, hogy
  /// éppen szól-e a stream — enélkül a gomb a szünet után is „szüneteltetés”
  /// maradna, amíg a Dart-oldal nem küld új metaadatot.
  private func sendRemoteCommand(_ name: String) {
    if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
      let rate: Double
      switch name {
      case "play":
        rate = 1
      case "pause", "stop":
        rate = 0
      default:
        let current = (info[MPNowPlayingInfoPropertyPlaybackRate] as? Double) ?? 1
        rate = current > 0 ? 0 : 1
      }
      info[MPNowPlayingInfoPropertyPlaybackRate] = rate
      MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    nowPlayingChannel?.invokeMethod("remoteCommand", arguments: name)
  }

  /// A „Most szól” panel frissítése / törlése.
  private func handleNowPlaying(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "metadata":
      let args = call.arguments as? [String: Any] ?? [:]
      let title = (args["title"] as? String) ?? ""
      let artist = (args["artist"] as? String) ?? "Real Hardstyle FM"
      let next = (args["next"] as? String) ?? ""
      guard !title.isEmpty else {
        result(nil)
        return
      }

      var info: [String: Any] = [
        MPMediaItemPropertyTitle: title,
        MPMediaItemPropertyArtist: artist,
        MPMediaItemPropertyAlbumTitle: "Real Hardstyle Radio",
        // Élő adás: a rendszer ne számoljon eltelt időt.
        MPNowPlayingInfoPropertyIsLiveStream: true,
      ]
      // ⚠️ A szünet ÁLLAPOTA megmarad a címfrissítéskor is (2026-10-03): a Dart
      // oldal 15 másodpercenként küld címet, és ha ilyenkor felülírnánk a
      // `playbackRate`-et, a zárképernyő gombja visszaváltana „szüneteltetés”-re
      // egy szünetelő rádiónál.
      if let existing = MPNowPlayingInfoCenter.default().nowPlayingInfo,
         let rate = existing[MPNowPlayingInfoPropertyPlaybackRate] as? Double {
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
      } else {
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1
      }
      if !next.isEmpty {
        info[MPMediaItemPropertyAlbumTitle] = "Következő: \(next)"
      }
      if let artwork = UIImage(named: "RealHardstyleLogo") {
        info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
          artwork
        }
      }
      MPNowPlayingInfoCenter.default().nowPlayingInfo = info
      result(nil)

    case "clear":
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
