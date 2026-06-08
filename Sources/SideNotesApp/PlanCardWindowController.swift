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
        window = NSWindow(
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
        setPinned(viewModel.settings.isPinned)
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
        window.contentView = NSHostingView(
            rootView: SideBookmarkView {
                self.show()
            }
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
        let width: CGFloat = 34
        let height: CGFloat = 92
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

private struct SideBookmarkView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("◆")
                    .font(.system(size: 12, weight: .semibold))
                Text("计划")
                    .font(.system(size: 12, weight: .semibold))
                    .fixedSize()
            }
            .foregroundStyle(.primary)
            .frame(width: 34, height: 92)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            if isHovering {
                onTap()
            }
        }
        .help("显示 SideNotes 计划卡片")
    }
}
