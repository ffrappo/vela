//
//  PlayerOrientationPolicyTests.swift
//  YatteeTests
//
//  Verifies Vela's one-way automatic landscape policy.
//

#if os(iOS)

import Testing
@testable import Yattee

@Suite("Player orientation policy")
struct PlayerOrientationPolicyTests {
    @Test("Wide video enters landscape when expanded")
    func wideVideoEntersLandscape() {
        #expect(action(ratio: 16.0 / 9.0) == .requestLandscape)
    }

    @Test("Consecutive wide video stays landscape")
    func wideVideoHandoffStaysLandscape() {
        #expect(action(orientation: .landscape, ratio: 16.0 / 9.0) == .none)
    }

    @Test("Unknown ratio during handoff keeps current orientation")
    func loadingHandoffDoesNotRotate() {
        #expect(action(orientation: .landscape, ratio: nil) == .none)
    }

    @Test("Portrait video does not force landscape")
    func portraitVideoDoesNotRotate() {
        #expect(action(ratio: 9.0 / 16.0) == .none)
    }

    @Test("Square video does not force landscape")
    func squareVideoDoesNotRotate() {
        #expect(action(ratio: 1) == .none)
    }

    @Test("Disabled matching does not rotate")
    func disabledMatchingDoesNotRotate() {
        #expect(action(enabled: false, ratio: 16.0 / 9.0) == .none)
    }

    @Test("Picture in Picture owns presentation")
    func pictureInPictureDoesNotRotatePlayer() {
        #expect(action(pip: true, ratio: 16.0 / 9.0) == .none)
    }

    @Test("Collapsed player does not rotate browsing")
    func collapsedPlayerDoesNotRotate() {
        #expect(action(expanded: false, ratio: 16.0 / 9.0) == .none)
    }

    @Test("iPad is adaptive and never forced")
    func tabletDoesNotRotate() {
        #expect(action(phone: false, ratio: 16.0 / 9.0) == .none)
    }

    private func action(
        phone: Bool = true,
        expanded: Bool = true,
        pip: Bool = false,
        enabled: Bool = true,
        orientation: PlayerInterfaceOrientation = .portrait,
        ratio: Double?
    ) -> PlayerOrientationAction {
        PlayerOrientationPolicy.action(for: PlayerOrientationContext(
            isPhone: phone,
            isPlayerExpanded: expanded,
            isPiPActive: pip,
            rotatesToMatchAspectRatio: enabled,
            interfaceOrientation: orientation,
            videoAspectRatio: ratio
        ))
    }
}

#endif
