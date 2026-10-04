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
  private func sendRemoteCommand(_ name: String) {
    switch name {
    case "play":
      applyPlaybackState(.playing)
    case "pause":
      applyPlaybackState(.paused)
    case "stop":
      applyPlaybackState(.stopped)
    default:
      applyPlaybackState(lastPlaybackState == .playing ? .paused : .playing)
    }
    nowPlayingChannel?.invokeMethod("remoteCommand", arguments: name)
  }

  /// Az utoljára jelentett állapot — a `playbackRate` **ebből** számol.
  private var lastPlaybackState: MPNowPlayingPlaybackState = .stopped

  /// A „szívverés”: amíg a rádió nem áll le, néhány másodpercenként újra kiírjuk
  /// ugyanazt az állapotot.
  private var heartbeat: Timer?

  private func rate(for state: MPNowPlayingPlaybackState) -> Double {
    state == .playing ? 1.0 : 0.0
  }

  /// A zárképernyő **állapota** — ebből rajzolja az iOS a gombokat.
  ///
  /// ⚠️ MÉRT GYÖKÉR (2026-10-04, a tulajdonos jelzése: *„play van meg stop és ha
  /// rányomok a playre, egy pillre pause lesz belőle aztán visszaáll … és szól a
  /// rádió”*): a zárképernyő a **`playbackRate`-ből** rajzol (1 = szól → pause
  /// gomb, 0 = áll → play gomb), és a `playbackRate` **beleragadt 0-ba**: a
  /// `metadata` (15 másodpercenként) szándékosan **megőrizte** a szótárban lévő
  /// régi értéket, a „szól” állapotot pedig csak **egyszer**, a kattintás
  /// pillanatában írtuk ki — a hang viszont csak a stream betöltése **után**
  /// indul el, ezért az iOS visszaállította a play gombot.
  ///
  /// Mostantól **egy helyen** dől el (`applyPlaybackState`): az állapot, a
  /// `playbackRate` és a szívverés is innen indul.
  private func applyPlaybackState(_ state: MPNowPlayingPlaybackState) {
    lastPlaybackState = state
    MPNowPlayingInfoCenter.default().playbackState = state
    writePlaybackRate()
    NSLog("HUHS mostszol: state=\(state.rawValue) rate=\(rate(for: state))")
    refreshHeartbeat()
  }

  /// A `playbackRate` kiírása a „Most szól” szótárba — **mindig az állapotból**.
  private func writePlaybackRate() {
    guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
    info[MPNowPlayingInfoPropertyPlaybackRate] = rate(for: lastPlaybackState)
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  /// A szívverés beállítása: álló rádiónál nincs, szólónál/szüneteltnél 5
  /// másodpercenként ismétel.
  private func refreshHeartbeat() {
    heartbeat?.invalidate()
    heartbeat = nil
    guard lastPlaybackState != .stopped else { return }
    heartbeat = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      MPNowPlayingInfoCenter.default().playbackState = self.lastPlaybackState
      self.writePlaybackRate()
    }
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
        // ⚠️ A `playbackRate` MINDIG az utoljára jelentett állapotból jön
        // (2026-10-04): a régi érték megőrzése volt az a hiba, amitől a
        // zárképernyő play gombja „beragadt” egy szóló rádió mellett.
        MPNowPlayingInfoPropertyPlaybackRate: rate(for: lastPlaybackState),
      ]
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

    // ⚠️ A zárképernyő gombjainak az ÁLLAPOTA (2026-10-03/04): a Dart-oldal a
    // rádió minden állapotváltásakor, a hang tényleges indulásakor és 5
    // másodpercenként küldi — enélkül a panel „play” gombot mutat egy szóló
    // rádión (a tulajdonos jelzése: *„nincs pause gomb”*).
    case "state":
      let args = call.arguments as? [String: Any] ?? [:]
      switch (args["state"] as? String) ?? "" {
      case "playing":
        applyPlaybackState(.playing)
      case "paused":
        applyPlaybackState(.paused)
      case "stopped":
        applyPlaybackState(.stopped)
      default:
        break
      }
      result(nil)

    case "clear":
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
      applyPlaybackState(.stopped)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
