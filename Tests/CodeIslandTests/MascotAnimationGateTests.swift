import XCTest
@testable import CodeIsland

@MainActor
final class MascotAnimationGateTests: XCTestCase {
    func testShouldAnimateOnlyWhenVisibleAndAwake() {
        XCTAssertTrue(MascotAnimationGate.shouldAnimate(isVisible: true, isAwake: true))
        XCTAssertFalse(MascotAnimationGate.shouldAnimate(isVisible: false, isAwake: true))
        XCTAssertFalse(MascotAnimationGate.shouldAnimate(isVisible: true, isAwake: false))
        XCTAssertFalse(MascotAnimationGate.shouldAnimate(isVisible: false, isAwake: false))
    }

    func testHidingPanelStopsAnimationsWithoutBumpingEpoch() {
        let gate = MascotAnimationGate.shared
        gate.setPanelVisible(true)
        let baseEpoch = gate.epoch

        gate.setPanelVisible(false)
        XCTAssertFalse(gate.animationsActive)
        // Hiding must not re-anchor — only re-showing/waking does.
        XCTAssertEqual(gate.epoch, baseEpoch)
    }

    func testReShowingPanelBumpsEpochToReAnchorSchedules() {
        let gate = MascotAnimationGate.shared
        gate.setPanelVisible(false)
        let hiddenEpoch = gate.epoch

        gate.setPanelVisible(true)
        XCTAssertTrue(gate.animationsActive)
        XCTAssertEqual(gate.epoch, hiddenEpoch + 1)
    }

    func testRepeatedSameVisibilityIsIdempotent() {
        let gate = MascotAnimationGate.shared
        gate.setPanelVisible(true)
        let epoch = gate.epoch
        gate.setPanelVisible(true)
        XCTAssertEqual(gate.epoch, epoch)
    }

    /// #299 — a live TimelineView keeps SwiftUI's update machinery on a display
    /// link and re-runs the panel's whole layout pass every cycle, which is the
    /// bulk of the idle CPU baseline. A collapsed island with nothing running
    /// holds a static frame instead.
    func testSettledIslandStopsAnimationsEvenWhileVisibleAndAwake() {
        XCTAssertFalse(
            MascotAnimationGate.shouldAnimate(isVisible: true, isAwake: true, isIdleSettled: true)
        )
        XCTAssertTrue(
            MascotAnimationGate.shouldAnimate(isVisible: true, isAwake: true, isIdleSettled: false)
        )
    }

    func testLeavingTheSettledStateReAnchorsSchedules() {
        let gate = MascotAnimationGate.shared
        gate.setPanelVisible(true)
        gate.setIdleSettled(true)
        XCTAssertFalse(gate.animationsActive)
        let settledEpoch = gate.epoch

        gate.setIdleSettled(false)
        XCTAssertTrue(gate.animationsActive)
        XCTAssertEqual(
            gate.epoch,
            settledEpoch + 1,
            "resuming must re-anchor, or SwiftUI replays every tick missed while settled"
        )
    }

    func testReduceMotionHoldsTheMascotsStill() {
        XCTAssertFalse(MascotAnimationGate.shouldAnimate(isVisible: true, isAwake: true, reduceMotion: true))
        let gate = MascotAnimationGate.shared
        gate.setPanelVisible(true)
        gate.setIdleSettled(false)
        defer { gate.setReduceMotion(false) }
        gate.setReduceMotion(true)
        XCTAssertFalse(gate.animationsActive)
        let stillEpoch = gate.epoch
        gate.setReduceMotion(false)
        XCTAssertTrue(gate.animationsActive)
        XCTAssertEqual(gate.epoch, stillEpoch + 1, "resuming must re-anchor the schedules")
    }

    /// Settings → Mascots › "Animate while expanded" is opt-out: on by default,
    /// and the collapsed bar keeps animating when it is off.
    func testAnimateWhileExpandedIsOnByDefaultAndOptOut() {
        XCTAssertTrue(
            MascotAnimationGate.shouldAnimate(isVisible: true, isAwake: true, isExpanded: true)
        )
        XCTAssertFalse(
            MascotAnimationGate.shouldAnimate(
                isVisible: true, isAwake: true, isExpanded: true, animatesWhenExpanded: false
            ),
            "off must hold the mascots still while the panel is open"
        )
        XCTAssertTrue(
            MascotAnimationGate.shouldAnimate(
                isVisible: true, isAwake: true, isExpanded: false, animatesWhenExpanded: false
            ),
            "the collapsed bar keeps animating when the switch is off"
        )
    }

    func testTurningExpandedAnimationOffStopsItAndBackOnReAnchors() {
        let gate = MascotAnimationGate.shared
        gate.setPanelVisible(true)
        gate.setIdleSettled(false)
        gate.setExpanded(true)
        defer {
            gate.setAnimatesWhenExpanded(true)
            gate.setExpanded(false)
        }
        gate.setAnimatesWhenExpanded(true)
        XCTAssertTrue(gate.animationsActive)

        gate.setAnimatesWhenExpanded(false)
        XCTAssertFalse(gate.animationsActive, "expanded + switch off = static mascots")
        let pausedEpoch = gate.epoch

        gate.setAnimatesWhenExpanded(true)
        XCTAssertTrue(gate.animationsActive)
        XCTAssertEqual(gate.epoch, pausedEpoch + 1, "resuming must re-anchor the schedules")
    }

    func testLeavingExpandedStateResumesAnimationsWhenSwitchIsOff() {
        let gate = MascotAnimationGate.shared
        defer {
            gate.setAnimatesWhenExpanded(true)
            gate.setExpanded(false)
            gate.setIdleSettled(false)
        }
        gate.setPanelVisible(true)
        gate.setIdleSettled(false)
        gate.setAnimatesWhenExpanded(false)
        gate.setExpanded(true)
        XCTAssertFalse(gate.animationsActive)
        let pausedEpoch = gate.epoch

        gate.setExpanded(false)
        XCTAssertTrue(gate.animationsActive, "collapsing resumes the mascots")
        XCTAssertEqual(gate.epoch, pausedEpoch + 1, "resuming must re-anchor the schedules")
    }

    func testSettlingDoesNotReAnchor() {
        let gate = MascotAnimationGate.shared
        gate.setIdleSettled(false)
        let epoch = gate.epoch
        gate.setIdleSettled(true)
        XCTAssertEqual(gate.epoch, epoch)
        gate.setIdleSettled(false)
    }
}
