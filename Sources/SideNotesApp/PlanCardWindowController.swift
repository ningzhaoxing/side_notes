import AppKit
import SwiftUI
import SideNotesCore

@MainActor
final class PlanCardWindowController: NSObject {
    private let viewModel: PlanViewModel
    private let window: NSWindow
    private var isCollapsed = false
    var onPinToggle: ((Bool) -> Void)?
    var onEdit: (() -> Void)?
    var onSettings: (() -> Void)?

    init(viewModel: PlanViewModel) {
        self.viewModel = viewModel
        window = CardWindow(
            contentRect: viewModel.settings.cardFrame.nsRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = viewModel.settings.isPinned ? .floating : .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        installRootView()
    }

    func show() {
        isCollapsed = false
        window.isMovableByWindowBackground = true
        installRootView()
        window.level = viewModel.settings.isPinned ? .floating : .normal
        window.setFrame(visibleFrame(), display: true, animate: true)
        window.orderFrontRegardless()
    }

    func hide() {
        guard !viewModel.settings.isPinned else { return }
        showBookmark()
    }

    func setPinned(_ isPinned: Bool) {
        window.level = isPinned ? .floating : .normal
        if isPinned {
            if isCollapsed {
                show()
            }
        } else if window.isVisible, !isCollapsed {
            showBookmark()
        } else if !window.isVisible {
            showBookmark()
        }
    }

    func shouldAutoHide(mouseLocation: NSPoint) -> Bool {
        guard window.isVisible, !viewModel.settings.isPinned, !isCollapsed else {
            return false
        }
        return !window.frame.insetBy(dx: -80, dy: -80).contains(mouseLocation)
    }

    func resizeCard(to size: CGSize) {
        viewModel.setCardSize(size)
        installRootView()
        window.setFrame(resizedFrame(), display: true)
    }

    func showBookmark() {
        guard !viewModel.settings.isPinned else { return }
        isCollapsed = true
        window.isMovableByWindowBackground = false
        installBookmarkView()
        window.level = .floating
        window.setFrame(bookmarkFrame(), display: true, animate: true)
        window.orderFrontRegardless()
    }

    func hideBookmark() {
        if isCollapsed {
            window.orderOut(nil)
        }
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
                },
                onSettings: { [weak self] in
                    self?.onSettings?()
                },
                onResize: { [weak self] size in
                    self?.resizeCard(to: size)
                }
            )
        )
    }

    private func installBookmarkView() {
        window.contentView = DrawerHandleView(frame: NSRect(x: 0, y: 0, width: 38, height: 112)) { [weak self] in
            self?.show()
        }
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

    private func resizedFrame() -> NSRect {
        let width = viewModel.settings.cardFrame.width
        let height = viewModel.settings.cardFrame.height
        var frame = window.frame
        switch viewModel.settings.triggerSide {
        case .right:
            frame.origin.x = frame.maxX - width
        case .left:
            break
        }
        frame.size = NSSize(width: width, height: height)
        return frame
    }

    private func bookmarkFrame() -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let width: CGFloat = 38
        let height: CGFloat = 112
        let x: CGFloat
        switch viewModel.settings.triggerSide {
        case .right:
            x = frame.maxX - width
        case .left:
            x = frame.minX
        }
        let y = frame.minY + max(24, (frame.height - height) / 2)
        return NSRect(x: x, y: y, width: width, height: height)
    }
}

private final class CardWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class DrawerHandleView: NSView {
    private let onActivate: () -> Void
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, onActivate: @escaping () -> Void) {
        self.onActivate = onActivate
        super.init(frame: frame)
        wantsLayer = true
        toolTip = "显示 SideNotes 计划卡片"
        setAccessibilityRole(.button)
        setAccessibilityLabel("计划")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseEntered(with event: NSEvent) {
        onActivate()
    }

    override func mouseDown(with event: NSEvent) {
        onActivate()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 2, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 13, yRadius: 13)
        NSColor.windowBackgroundColor.withAlphaComponent(0.9).setFill()
        path.fill()
        NSColor.separatorColor.withAlphaComponent(0.8).setStroke()
        path.lineWidth = 1
        path.stroke()

        drawCentered("◆", y: bounds.midY + 16, size: 13, weight: .semibold)
        drawCentered("计划", y: bounds.midY - 14, size: 12, weight: .semibold)
    }

    private func drawCentered(_ text: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor.labelColor
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        attributed.draw(
            at: NSPoint(
                x: bounds.midX - textSize.width / 2,
                y: y - textSize.height / 2
            )
        )
    }
}
