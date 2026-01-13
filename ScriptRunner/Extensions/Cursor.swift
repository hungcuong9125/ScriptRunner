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
}
