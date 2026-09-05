//
//  ExpandedPlayerSheet+Orientation.swift
//  Yattee
//
//  iOS-specific orientation, fullscreen, and ambient glow functionality.
//

import SwiftUI

#if os(iOS)
import UIKit

extension ExpandedPlayerSheet {
    // MARK: - Safe Area Helpers

    /// Get safe area insets from the window.
    var windowSafeAreaInsets: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first?
            .safeAreaInsets ?? .zero
    }

    // MARK: - Orientation Lock

    /// Set up in-app orientation lock callback.
    func setupOrientationLockCallback() {
        DeviceRotationManager.shared.isOrientationLocked = { [weak appEnvironment] in
            appEnvironment?.settingsManager.inAppOrientationLock ?? false
        }
    }

    // MARK: - Fullscreen Toggle

    /// Toggle fullscreen by rotating between portrait and landscape.
    /// When orientation lock is enabled, locks to the target orientation before rotating
    /// (keeps orientation restricted the entire time, just changes which orientation is allowed).
    func toggleFullscreen() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }

        let orientationManager = OrientationManager.shared
        let requestedOrientation = orientationManager.effectiveOrPendingOrientation(in: windowScene)
        let isCurrentlyLandscape = requestedOrientation == .landscape ||
            requestedOrientation == .landscapeLeft ||
            requestedOrientation == .landscapeRight
        let isOrientationLocked = appEnvironment?.settingsManager.inAppOrientationLock ?? false

        MPVLogging.logTransition("toggleFullscreen",
            fromSize: windowScene.coordinateSpace.bounds.size,
            toSize: nil)

        if isCurrentlyLandscape {
            // Exit fullscreen and rotate to portrait.
            MPVLogging.log("toggleFullscreen: exiting to portrait")
            if isOrientationLocked {
                orientationManager.lock(to: .portrait)
            }
            orientationManager.request(
                .portrait,
                reason: "explicit fullscreen exit",
                priority: .explicit,
                scene: windowScene,
                unlockWhenApplied: isOrientationLocked
            )
        } else {
            // Enter fullscreen and rotate to landscape.
            let targetOrientation = Self.currentLandscapeInterfaceOrientation()
            MPVLogging.log("toggleFullscreen: entering landscape")
            if isOrientationLocked {
                orientationManager.lock(to: targetOrientation)
            }
            orientationManager.request(
                targetOrientation,
                reason: "explicit fullscreen entry",
                priority: .explicit,
                scene: windowScene
            )
        }
    }

    // MARK: - Rotation Monitoring

    /// Simplified rotation monitoring - handles layout transitions via accelerometer.
    func setupRotationMonitoring() {
        guard let appEnvironment else { return }

        MPVLogging.log("setupRotationMonitoring: starting")
        let rotationManager = DeviceRotationManager.shared

        // Set up callback for landscape detection (request landscape rotation)
        rotationManager.onLandscapeDetected = { [weak appEnvironment] in
            Task { @MainActor in
                guard let appEnvironment else { return }
                guard !appEnvironment.settingsManager.inAppOrientationLock else { return }

                let playerState = appEnvironment.playerService.state

                // Only rotate if we have a video playing
                guard playerState.currentVideo != nil,
                      playerState.pipState != .active else { return }

                // Request landscape rotation
                guard let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }) else { return }

                let isLandscape = OrientationManager.shared.effectiveOrientation(in: windowScene).isLandscape
                if !isLandscape {
                    let targetOrientation = Self.currentLandscapeInterfaceOrientation()
                    MPVLogging.logTransition("onLandscapeDetected: requesting landscape",
                        fromSize: windowScene.coordinateSpace.bounds.size, toSize: nil)
                    OrientationManager.shared.request(
                        targetOrientation,
                        reason: "physical landscape rotation",
                        scene: windowScene
                    )
                }
            }
        }

        // Set up callback for portrait detection (request portrait rotation)
        rotationManager.onPortraitDetected = { [weak appEnvironment] in
            Task { @MainActor in
                guard let appEnvironment else { return }
                guard !appEnvironment.settingsManager.inAppOrientationLock else { return }

                // Request portrait rotation
                guard let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }) else { return }

                let isLandscape = OrientationManager.shared.effectiveOrientation(in: windowScene).isLandscape
                if isLandscape {
                    MPVLogging.logTransition("onPortraitDetected: requesting portrait",
                        fromSize: windowScene.coordinateSpace.bounds.size, toSize: nil)
                    OrientationManager.shared.request(
                        .portrait,
                        reason: "physical portrait rotation",
                        scene: windowScene
                    )
                }
            }
        }

        // Set up callback for landscape-to-landscape rotation (rotate between left and right)
        rotationManager.onLandscapeOrientationChanged = { [weak appEnvironment] newOrientation in
            Task { @MainActor in
                guard let appEnvironment else { return }
                guard !appEnvironment.settingsManager.inAppOrientationLock else { return }

                guard let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }) else { return }

                // Device and interface orientations are inverted
                let targetOrientation: UIInterfaceOrientationMask = switch newOrientation {
                case .landscapeLeft:
                    .landscapeRight
                case .landscapeRight:
                    .landscapeLeft
                default:
                    .landscape
                }

                MPVLogging.logTransition("onLandscapeOrientationChanged: \(newOrientation.rawValue)")
                OrientationManager.shared.request(
                    targetOrientation,
                    reason: "physical landscape side change",
                    scene: windowScene
                )
            }
        }

        // Always start monitoring
        rotationManager.startMonitoring()
    }

    /// Applies Vela's automatic wide-video policy. This method can request
    /// landscape, but it deliberately never requests portrait. That one-way
    /// rule keeps consecutive landscape videos fullscreen through EOF, queue,
    /// loading, and aspect-ratio handoffs.
    func reconcileVideoOrientation() {
        guard let appEnvironment,
              UIDevice.current.userInterfaceIdiom == .phone,
              let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }

        let isLandscape = OrientationManager.shared.effectiveOrientation(in: windowScene).isLandscape
        let state = appEnvironment.playerService.state

        let context = PlayerOrientationContext(
            isPhone: true,
            isPlayerExpanded: appEnvironment.navigationCoordinator.isPlayerExpanded,
            isPiPActive: state.pipState == .active,
            rotatesToMatchAspectRatio: appEnvironment.settingsManager.rotateToMatchAspectRatio,
            interfaceOrientation: isLandscape ? .landscape : .portrait,
            videoAspectRatio: state.videoAspectRatio,
            aspectRatioMatchesCurrentVideo: state.videoAspectRatio != nil
        )

        guard PlayerOrientationPolicy.action(for: context) == .requestLandscape else { return }

        let targetOrientation = Self.currentLandscapeInterfaceOrientation()
        if appEnvironment.settingsManager.inAppOrientationLock {
            OrientationManager.shared.lock(to: targetOrientation)
        }
        OrientationManager.shared.request(
            targetOrientation,
            reason: "wide video started while expanded",
            priority: .automatic,
            scene: windowScene
        )
    }

    /// Get the interface orientation mask matching the device's current landscape orientation.
    static func currentLandscapeInterfaceOrientation() -> UIInterfaceOrientationMask {
        let deviceOrientation = DeviceRotationManager.shared.detectedOrientation
        // Device and interface orientations are inverted
        switch deviceOrientation {
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return .landscape // Fallback to any landscape
        }
    }

}

#endif
