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

    case "clear":
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
