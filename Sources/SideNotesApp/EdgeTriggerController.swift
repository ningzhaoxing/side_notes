import AppKit
import SideNotesCore

@MainActor
final class EdgeTriggerController {
    private var triggerSide: TriggerSide
    private let onShow: () -> Void
    private let onHideCheck: (NSPoint) -> Void
    private var timer: Timer?

    init(triggerSide: TriggerSide, onShow: @escaping () -> Void, onHideCheck: @escaping (NSPoint) -> Void) {
        self.triggerSide = triggerSide
        self.onShow = onShow
        self.onHideCheck = onHideCheck
    }

    func setTriggerSide(_ triggerSide: TriggerSide) {
        self.triggerSide = triggerSide
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
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else {
            return
        }

        let frame = screen.frame
        let threshold: CGFloat = 12
        switch triggerSide {
        case .right where mouse.x >= frame.maxX - threshold:
            onShow()
        case .left where mouse.x <= frame.minX + threshold:
            onShow()
        default:
            onHideCheck(mouse)
        }
    }
}
