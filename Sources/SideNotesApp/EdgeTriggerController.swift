import AppKit

@MainActor
final class EdgeTriggerController {
    private let onHideCheck: (NSPoint) -> Void
    private var timer: Timer?

    init(onHideCheck: @escaping (NSPoint) -> Void) {
        self.onHideCheck = onHideCheck
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let mouse = NSEvent.mouseLocation
        onHideCheck(mouse)
    }
}
