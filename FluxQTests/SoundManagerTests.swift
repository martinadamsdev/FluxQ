import Testing
@testable import FluxQ

@Suite("SoundManager Tests")
struct SoundManagerTests {

    @Test("可用系统声音列表非空")
    func availableSystemSoundsNotEmpty() {
        #expect(!SoundManager.availableSystemSounds.isEmpty)
    }

    @Test("可用系统声音包含 Glass（默认音效）")
    func availableSystemSoundsContainsGlass() {
        #expect(SoundManager.availableSystemSounds.contains("Glass"))
    }

    @Test("可用系统声音包含所有预期名称")
    func availableSystemSoundsContainsExpected() {
        let expected = ["Glass", "Ping", "Pop", "Purr", "Tink"]
        for name in expected {
            #expect(SoundManager.availableSystemSounds.contains(name))
        }
    }
}
