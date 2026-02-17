import Foundation
import Combine
import FluxQServices

#if os(macOS)
import AppKit
#elseif os(iOS)
import AudioToolbox
#endif

@MainActor
final class SoundManager: ObservableObject {

    static let shared = SoundManager()

    /// 可选的系统声音名称列表（macOS）
    static let availableSystemSounds: [String] = [
        "Glass", "Ping", "Pop", "Purr", "Tink",
        "Blow", "Bottle", "Frog", "Funk", "Hero",
        "Morse", "Sosumi", "Submarine", "Basso"
    ]

    private var throttle: SoundThrottle

    private init(throttleInterval: TimeInterval = 3.0) {
        self.throttle = SoundThrottle(interval: throttleInterval)
    }

    /// 播放提示音（带节流）
    func play(soundName: String = "Glass", force: Bool = false) {
        guard force || throttle.shouldAllow() else { return }

        #if os(macOS)
        NSSound(named: NSSound.Name(soundName))?.play()
        #elseif os(iOS)
        AudioServicesPlaySystemSound(1007)
        #endif
    }
}
