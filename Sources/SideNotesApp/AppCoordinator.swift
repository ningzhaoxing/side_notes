import AppKit
import SwiftUI
import SideNotesCore

@MainActor
final class AppCoordinator: NSObject {
    static let showCardNotificationName = Notification.Name("com.ningzhaoxing.sidenotes.showCard")

    private let viewModel: PlanViewModel
    private let cardController: PlanCardWindowController
    private lazy var editorWindow: NSWindow = makeEditorWindow()
    private var edgeTrigger: EdgeTriggerController?
    private var statusItem: NSStatusItem?
    private var pendingHideWorkItem: DispatchWorkItem?

    init(store: PlanStore) {
        let viewModel = PlanViewModel(store: store)
        self.viewModel = viewModel
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
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func start() {
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
            editorWindow.center()
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

    @objc private func showEditorFromMenu() {
        showEditor()
    }

    @objc private func quitFromMenu() {
        quit()
    }

    private func quit() {
        cancelPendingHide()
        edgeTrigger?.stop()
        NSApp.terminate(nil)
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
        window.center()
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
}
