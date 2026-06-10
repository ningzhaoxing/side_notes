import AppKit
import Combine
import SwiftUI
import SideNotesCore

@MainActor
final class AppCoordinator: NSObject {
    static let showCardNotificationName = AppRuntimeSignal.showCardNotificationName
    static let quitNotificationName = AppRuntimeSignal.quitNotificationName

    private let viewModel: PlanViewModel
    private let cardController: PlanCardWindowController
    private lazy var editorWindow: NSWindow = makeEditorWindow()
    private var edgeTrigger: EdgeTriggerController?
    private var statusItem: NSStatusItem?
    private var pendingHideWorkItem: DispatchWorkItem?
    private var quitRequestTimer: Timer?
    private var isApplyingEditorFrame = false
    private var settingsCancellable: AnyCancellable?
    private var lastAppliedSettings: AppSettings
    private let launchTimestamp = Date().timeIntervalSince1970

    init(store: PlanStore) {
        let viewModel = PlanViewModel(store: store)
        viewModel.validateWindowFrames(visibleFrames: NSScreen.storedVisibleFrames)
        self.viewModel = viewModel
        lastAppliedSettings = viewModel.settings
        cardController = PlanCardWindowController(viewModel: viewModel)
        super.init()
        cardController.onPinToggle = { [weak self] isPinned in
            self?.cardController.setPinned(isPinned)
        }
        cardController.onEdit = { [weak self] in
            self?.showEditor()
        }
        cardController.onSettings = { [weak self] in
            self?.showEditor(tab: .appearance)
        }
        cardController.onQuit = { [weak self] in
            self?.quit()
        }
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(showCardFromDistributedNotification(_:)),
            name: Self.showCardNotificationName,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(quitFromDistributedNotification(_:)),
            name: Self.quitNotificationName,
            object: nil
        )
        settingsCancellable = viewModel.$settings
            .dropFirst()
            .sink { [weak self] settings in
                Task { @MainActor in
                    self?.applyLiveSettings(settings)
                }
            }
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func start() {
        startQuitRequestMonitor()
        if ProcessInfo.processInfo.environment["SIDE_NOTES_DISABLE_STATUS_ITEM"] == "1" {
            statusItem = nil
        } else {
            installStatusItem()
        }
        cardController.show()
        if !viewModel.settings.isPinned {
            cardController.hide()
        }

        edgeTrigger = EdgeTriggerController(
            triggerSide: viewModel.settings.triggerSide,
            onShow: { [weak self] in
                self?.cancelPendingHide()
                self?.cardController.show()
            },
            onHideCheck: { [weak self] mouseLocation in
                guard let self else { return }
                if self.cardController.shouldAutoHide(mouseLocation: mouseLocation) {
                    self.scheduleHide()
                } else {
                    self.cancelPendingHide()
                }
            }
        )
        edgeTrigger?.start()
    }

    func showCard() {
        cancelPendingHide()
        cardController.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    func showEditor(tab: EditorTab? = nil) {
        if let tab {
            viewModel.editorTab = tab
        }
        if !editorWindow.isVisible {
            applyEditorFrame(restoredEditorFrame())
        }
        editorWindow.makeKeyAndOrderFront(nil)
        editorWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showCardFromMenu() {
        showCard()
    }

    @objc private func showCardFromDistributedNotification(_ notification: Notification) {
        showCard()
    }

    @objc private func quitFromDistributedNotification(_ notification: Notification) {
        quit(broadcast: false)
    }

    @objc private func showEditorFromMenu() {
        showEditor()
    }

    @objc private func quitFromMenu() {
        quit()
    }

    private func quit(broadcast: Bool = true) {
        if broadcast {
            AppRuntimeSignal.writeQuitRequest()
            DistributedNotificationCenter.default().post(
                name: Self.quitNotificationName,
                object: nil
            )
        }
        cancelPendingHide()
        quitRequestTimer?.invalidate()
        quitRequestTimer = nil
        edgeTrigger?.stop()
        NSApp.terminate(nil)
    }

    private func startQuitRequestMonitor() {
        quitRequestTimer?.invalidate()
        quitRequestTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, AppRuntimeSignal.hasPendingQuitRequest(after: self.launchTimestamp) else { return }
            Task { @MainActor in
                self.quit(broadcast: false)
            }
        }
    }

    private func scheduleHide() {
        guard pendingHideWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.pendingHideWorkItem = nil
                if self.cardController.shouldAutoHide(mouseLocation: NSEvent.mouseLocation) {
                    self.cardController.hide()
                }
            }
        }
        pendingHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    private func cancelPendingHide() {
        pendingHideWorkItem?.cancel()
        pendingHideWorkItem = nil
    }

    private func applyLiveSettings(_ settings: AppSettings) {
        let triggerSideChanged = settings.triggerSide != lastAppliedSettings.triggerSide
        lastAppliedSettings = settings
        edgeTrigger?.setTriggerSide(settings.triggerSide)
        cardController.updateForSettingsChange(repositionForTriggerSideChange: triggerSideChanged)
    }

    private func makeEditorWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: viewModel.settings.editorFrame.nsRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SideNotes 编辑"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.delegate = self
        window.contentView = NSHostingView(rootView: EditorView(viewModel: viewModel))
        return window
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "SideNotes"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示计划卡", action: #selector(showCardFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "打开编辑器", action: #selector(showEditorFromMenu), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitFromMenu), keyEquivalent: "q"))
        for item in menu.items {
            item.target = self
        }
        item.menu = menu
        statusItem = item
    }

    private func restoredEditorFrame() -> NSRect {
        let frame = viewModel.settings.editorFrame.nsRect
        if frameIsVisible(frame) {
            return frame
        }
        var settings = viewModel.settings
        settings.validate(visibleFrames: NSScreen.storedVisibleFrames)
        viewModel.setEditorFrame(settings.editorFrame, visibleFrames: NSScreen.storedVisibleFrames)
        return settings.editorFrame.nsRect
    }

    private func applyEditorFrame(_ frame: NSRect) {
        isApplyingEditorFrame = true
        editorWindow.setFrame(frame, display: false)
        DispatchQueue.main.async { [weak self] in
            self?.isApplyingEditorFrame = false
        }
    }

    private func persistEditorFrameIfNeeded(_ window: NSWindow) {
        guard window === editorWindow, !isApplyingEditorFrame else { return }
        viewModel.setEditorFrame(window.frame.storedRect, visibleFrames: NSScreen.storedVisibleFrames)
    }

    private func frameIsVisible(_ frame: NSRect) -> Bool {
        let storedFrame = frame.storedRect
        return NSScreen.storedVisibleFrames.contains {
            storedFrame.isUsablyVisible(in: $0)
        }
    }
}

extension AppCoordinator: NSWindowDelegate {
    nonisolated func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        Task { @MainActor in
            persistEditorFrameIfNeeded(window)
        }
    }

    nonisolated func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        Task { @MainActor in
            persistEditorFrameIfNeeded(window)
        }
    }
}
