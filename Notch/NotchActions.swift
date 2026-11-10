import SwiftUI

/// Things views inside the notch can ask of their screen's controller.
struct NotchActions: Sendable {
    /// Keep the notch open (or release it) for a reason from SPEC §4.2.
    var setCloseBlocker: @MainActor @Sendable (CloseBlocker, Bool) -> Void = { _, _ in }
    /// Changes when the user clicks outside the notch: popups should close.
    var dismissToken = 0
}

extension EnvironmentValues {
    @Entry var notchActions = NotchActions()
}
