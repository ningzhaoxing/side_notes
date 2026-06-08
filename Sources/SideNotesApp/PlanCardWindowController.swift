import AppKit
import SwiftUI
import SideNotesCore

@MainActor
final class PlanCardWindowController {
    private let viewModel: PlanViewModel
    private let window: NSWindow
    var onPinToggle: ((Bool) -> Void)?
    var onEdit: (() -> Void)?

    init(viewModel: PlanViewModel) {
        self.viewModel = viewModel
        window = NSWindow(
            contentRect: viewModel.settings.cardFrame.nsRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = viewModel.settings.isPinned ? .floating : .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        installRootView()
    }

    func show() {
        installRootView()
        setPinned(viewModel.settings.isPinned)
        window.setFrame(visibleFrame(), display: true, animate: true)
        window.orderFrontRegardless()
    }

    func hide() {
        guard !viewModel.settings.isPinned else { return }
        window.orderOut(nil)
    }

    func setPinned(_ isPinned: Bool) {
        window.level = isPinned ? .floating : .normal
    }

    func shouldAutoHide(mouseLocation: NSPoint) -> Bool {
        guard window.isVisible, !viewModel.settings.isPinned else {
            return false
        }
        return !window.frame.insetBy(dx: -80, dy: -80).contains(mouseLocation)
    }

    private func installRootView() {
        window.contentView = NSHostingView(
            rootView: PlanCardView(
                viewModel: viewModel,
                onPinToggle: { [weak self] isPinned in
                    self?.onPinToggle?(isPinned)
                },
                onEdit: { [weak self] in
                    self?.onEdit?()
                }
            )
        )
    }

    private func visibleFrame() -> NSRect {
        let screen = NSScreen.screens.first { $0.visibleFrame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let width = viewModel.settings.cardFrame.width
        let height = min(viewModel.settings.cardFrame.height, frame.height - 48)
        let x: Double
        switch viewModel.settings.triggerSide {
        case .right:
            x = frame.maxX - width - 18
        case .left:
            x = frame.minX + 18
        }
        let y = frame.minY + max(24, (frame.height - height) / 2)
        return NSRect(x: x, y: y, width: width, height: height)
    }
}

