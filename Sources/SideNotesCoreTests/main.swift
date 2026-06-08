import Foundation
import SideNotesCore

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TestFailure(description: message)
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
    if actual != expected {
        throw TestFailure(description: "\(message): expected \(expected), got \(actual)")
    }
}

func expectEqual(_ actual: Double, _ expected: Double, accuracy: Double, _ message: String) throws {
    if abs(actual - expected) > accuracy {
        throw TestFailure(description: "\(message): expected \(expected), got \(actual)")
    }
}

func testDefaultSettingsAreReadableAndUsable() throws {
    let settings = AppSettings.defaults()

    try expectEqual(settings.triggerSide, .right, "default trigger side")
    try expect(!settings.isPinned, "default pinned state")
    try expectEqual(settings.visibleSide, .front, "default visible side")
    try expectEqual(settings.cardOpacity, 0.94, accuracy: 0.001, "default opacity")
    try expectEqual(settings.cardCornerRadius, 22, accuracy: 0.001, "default corner radius")
}

func testAppearanceSettingsClampToReadableRanges() throws {
    var settings = AppSettings.defaults()
    settings.cardOpacity = 0.1
    settings.cardCornerRadius = -20

    settings.validate()

    try expectEqual(settings.cardOpacity, 0.35, accuracy: 0.001, "minimum opacity clamp")
    try expectEqual(settings.cardCornerRadius, 4, accuracy: 0.001, "minimum corner radius clamp")

    settings.cardOpacity = 2
    settings.cardCornerRadius = 200

    settings.validate()

    try expectEqual(settings.cardOpacity, 1, accuracy: 0.001, "maximum opacity clamp")
    try expectEqual(settings.cardCornerRadius, 48, accuracy: 0.001, "maximum corner radius clamp")
}

func testWindowFrameOutsideScreensFallsBackToDefault() throws {
    var settings = AppSettings.defaults()
    settings.cardFrame = StoredRect(x: -9_000, y: -9_000, width: 320, height: 520)

    settings.validate(visibleFrames: [
        StoredRect(x: 0, y: 0, width: 1_440, height: 900)
    ])

    try expectEqual(settings.cardFrame.x, 1_088, accuracy: 0.001, "fallback x")
    try expectEqual(settings.cardFrame.y, 160, accuracy: 0.001, "fallback y")
    try expectEqual(settings.cardFrame.width, 320, accuracy: 0.001, "fallback width")
    try expectEqual(settings.cardFrame.height, 580, accuracy: 0.001, "fallback height")
}

let tests: [(String, () throws -> Void)] = [
    ("default settings are readable and usable", testDefaultSettingsAreReadableAndUsable),
    ("appearance settings clamp to readable ranges", testAppearanceSettingsClampToReadableRanges),
    ("window frame outside screens falls back to default", testWindowFrameOutsideScreensFallsBackToDefault)
]

var failures: [String] = []

for (name, test) in tests {
    do {
        try test()
        print("PASS \(name)")
    } catch {
        failures.append("FAIL \(name): \(error)")
    }
}

if failures.isEmpty {
    print("All \(tests.count) SideNotesCore tests passed.")
} else {
    failures.forEach { print($0) }
    exit(1)
}
