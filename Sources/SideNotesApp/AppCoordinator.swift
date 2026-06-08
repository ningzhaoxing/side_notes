import AppKit
import SwiftUI
import SideNotesCore

@MainActor
final class AppCoordinator: NSObject {
    private let viewModel: PlanViewModel
    private let cardController: PlanCardWindowController
    private lazy var editorWindow: NSWindow = makeEditorWindow()
    private var edgeTrigger: EdgeTriggerController?
    private var statusItem: NSStatusItem?

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
                self?.cardController.show()
            },
            onHideCheck: { [weak self] mouseLocation in
                guard let self else { return }
                if self.cardController.shouldAutoHide(mouseLocation: mouseLocation) {
                    self.cardController.hide()
                }
            }
        )
        edgeTrigger?.start()
    }

    func showCard() {
        cardController.show()
        NSApp.activate()
    }

    func showEditor() {
        editorWindow.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    @objc private func showCardFromMenu() {
        showCard()
    }

    @objc private func showEditorFromMenu() {
        showEditor()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func makeEditorWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: viewModel.settings.editorFrame.nsRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SideNotes 编辑"
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
