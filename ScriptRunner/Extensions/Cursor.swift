import SwiftUI
import AppKit

extension View {
    /// Adds a pointing hand cursor when hovering over the view
    func pointingHandCursor() -> some View {
        self.onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }

    /// Applies a custom cursor while hovering over the view
    func hoverCursor(_ cursor: NSCursor) -> some View {
        self.onHover { isHovering in
            if isHovering {
                cursor.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}
