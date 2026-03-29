import SwiftUI
import AppKit

extension View {
    /// Adds a pointing hand cursor when hovering over the view
    func pointingHandCursor() -> some View {
        self.onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    /// Applies a custom cursor while hovering over the view
    func hoverCursor(_ cursor: NSCursor) -> some View {
        self.onHover { isHovering in
            if isHovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
