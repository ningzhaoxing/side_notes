import AppKit
import SideNotesCore

extension StoredRect {
    var nsRect: NSRect {
        NSRect(x: x, y: y, width: width, height: height)
    }
}

extension NSRect {
    var storedRect: StoredRect {
        StoredRect(
            x: origin.x,
            y: origin.y,
            width: size.width,
            height: size.height
        )
    }
}

extension NSScreen {
    static var storedVisibleFrames: [StoredRect] {
        screens.map { $0.visibleFrame.storedRect }
    }
}
