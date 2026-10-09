import IOKit.pwr_mgt
import Foundation

final class SleepPreventer {
    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private var systemActive = false
    private var displayActive = false

    func prevent(keepDisplayAwake: Bool) {
        if !systemActive {
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "VideoSecurity recording active" as CFString,
                &systemAssertionID
            )
            systemActive = result == kIOReturnSuccess
        }
        applyDisplayAssertion(keepDisplayAwake)
    }

    func allow() {
        applyDisplayAssertion(false)
        guard systemActive else { return }
        IOPMAssertionRelease(systemAssertionID)
        systemActive = false
    }

    private func applyDisplayAssertion(_ keepDisplayAwake: Bool) {
        if keepDisplayAwake {
            guard !displayActive else { return }
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "VideoSecurity keep display awake" as CFString,
                &displayAssertionID
            )
            displayActive = result == kIOReturnSuccess
        } else if displayActive {
            IOPMAssertionRelease(displayAssertionID)
            displayActive = false
        }
    }
}
