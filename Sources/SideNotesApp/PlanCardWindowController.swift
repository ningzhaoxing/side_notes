import AppKit
import SwiftUI
import SideNotesCore

@MainActor
final class PlanCardWindowController: NSObject {
    private let viewModel: PlanViewModel
    private let window: NSWindow
    private var isCollapsed = false
    private var isApplyingProgrammaticFrame = false
    var onPinToggle: ((Bool) -> Void)?
    var onEdit: (() -> Void)?
    var onSettings: (() -> Void)?
    var onQuit: (() -> Void)?

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
        window.delegate = self
        installRootView()
    }

    func show() {
        window.level = viewModel.settings.isPinned ? .floating : .normal
        guard !window.isVisible || isCollapsed else {
            window.orderFrontRegardless()
            return
        }
        isCollapsed = false
        window.isMovableByWindowBackground = true
        installRootView()
        applyFrame(cardPresentationFrame(), animate: true)
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
        guard !isTextEditing else {
            return false
        }
        return !window.frame.insetBy(dx: -80, dy: -80).contains(mouseLocation)
    }

    func resizeCard(to size: CGSize) {
        let frame = StoredRect(x: window.frame.minX, y: window.frame.minY, width: size.width, height: size.height)
        viewModel.setCardFrame(frame, visibleFrames: NSScreen.storedVisibleFrames)
        installRootView()
        applyFrame(resizedFrame(), animate: false)
    }

    func showBookmark() {
        guard !viewModel.settings.isPinned else { return }
        guard !window.isVisible || !isCollapsed else {
            window.orderFrontRegardless()
            return
        }
        isCollapsed = true
        window.isMovableByWindowBackground = false
        installBookmarkView()
        window.level = .floating
        applyFrame(bookmarkFrame(), animate: true)
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
                onQuit: { [weak self] in
                    self?.onQuit?()
                },
                onResize: { [weak self] size in
                    self?.resizeCard(to: size)
                }
            )
        )
    }

    private func installBookmarkView() {
        window.contentView = DrawerHandleButton(frame: NSRect(x: 0, y: 0, width: 38, height: 112), onActivate: { [weak self] in
            self?.show()
        }, onQuit: { [weak self] in
            self?.onQuit?()
        })
    }

    private func cardPresentationFrame() -> NSRect {
        let storedFrame = viewModel.settings.cardFrame.nsRect
        if viewModel.settings.isPinned, frameIsVisible(storedFrame) {
            return storedFrame
        }
        return edgeFrame()
    }

    private func edgeFrame() -> NSRect {
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

    private func frameIsVisible(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
    }

    private func applyFrame(_ frame: NSRect, animate: Bool) {
        isApplyingProgrammaticFrame = true
        window.setFrame(frame, display: true, animate: animate)
        DispatchQueue.main.asyncAfter(deadline: .now() + (animate ? 0.45 : 0.05)) { [weak self] in
            self?.isApplyingProgrammaticFrame = false
        }
    }

    private func persistCardFrameIfNeeded() {
        guard !isApplyingProgrammaticFrame, !isCollapsed else { return }
        viewModel.setCardFrame(window.frame.storedRect, visibleFrames: NSScreen.storedVisibleFrames)
    }

    private var isTextEditing: Bool {
        window.firstResponder is NSTextView
    }
}

extension PlanCardWindowController: NSWindowDelegate {
    nonisolated func windowDidMove(_ notification: Notification) {
        Task { @MainActor in
            persistCardFrameIfNeeded()
        }
    }

    nonisolated func windowDidResize(_ notification: Notification) {
        Task { @MainActor in
            persistCardFrameIfNeeded()
        }
    }
}

private final class CardWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class DrawerHandleButton: NSButton {
    private let onActivate: () -> Void
    private let onQuit: () -> Void
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, onActivate: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onActivate = onActivate
        self.onQuit = onQuit
        super.init(frame: frame)
        wantsLayer = true
        title = ""
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)
        target = self
        action = #selector(activate)
        sendAction(on: [.leftMouseDown])
        toolTip = "显示 SideNotes 计划卡片"
        setAccessibilityLabel("计划")
        installMenu()
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

    override func accessibilityPerformPress() -> Bool {
        onActivate()
        return true
    }

    @objc private func activate() {
        onActivate()
    }

    @objc private func quitSideNotes() {
        onQuit()
    }

    private func installMenu() {
        let menu = NSMenu()
        let showItem = NSMenuItem(title: "显示计划卡", action: #selector(activate), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出 SideNotes", action: #selector(quitSideNotes), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        self.menu = menu
    }

    override func mouseEntered(with event: NSEvent) {
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
