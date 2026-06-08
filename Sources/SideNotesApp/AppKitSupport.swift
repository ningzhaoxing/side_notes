import AppKit
import SideNotesCore

extension StoredRect {
    var nsRect: NSRect {
        NSRect(x: x, y: y, width: width, height: height)
    }
}
