import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ── Audio session ─────────────────────────────────────────────────────
    // .playback   : audio continues when device is silenced or screen locks
    // .moviePlayback : optimises routing for video content
    // .allowAirPlay : enables AirPlay / Apple TV casting
    // .allowBluetooth/.allowBluetoothA2DP : wireless headphones & speakers
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode: .moviePlayback,
        options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
      )
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      NSLog("[WiseTVPlayer] AVAudioSession setup failed: \(error)")
    }

    GeneratedPluginRegistrant.register(with: self)
    let registered = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Register the Now Playing / lock-screen handler after Flutter engine is ready.
    if let vc = window?.rootViewController as? FlutterViewController {
      NowPlayingHandler.shared.register(with: vc)
    }

    return registered
  }

  // ── Remote-control events (lock-screen media controls) ────────────────
  // Flutter / media_kit handle this through the platform channel;
  // we just need to make sure the app can become the "now playing" target.
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    UIApplication.shared.beginReceivingRemoteControlEvents()
    becomeFirstResponder()
  }

  override var canBecomeFirstResponder: Bool { true }
}
