//
//  OrientationManager.swift
//  Yattee
//
//  Provides supported interface orientations for the app.
//  Supports in-app orientation locking when the player is visible.
//

#if os(iOS)

import UIKit

/// Provides supported interface orientations.
/// Supports in-app orientation locking to the current orientation.
@MainActor
final class OrientationManager {
    static let shared = OrientationManager()

    private init() {}

    /// The orientation to lock to when `isLocked` is true.
    /// Updated when orientation lock is enabled to capture current orientation.
    private var lockedOrientation: UIInterfaceOrientationMask?

    /// Whether orientation is currently locked.
    private(set) var isLocked: Bool = false

    /// Lock orientation to the current orientation
    func lock() {
        guard !isLocked else { return }
        lockedOrientation = currentInterfaceOrientationMask
        isLocked = true
        notifyOrientationChange()
    }

    /// Lock to a specific orientation
    func lock(to orientation: UIInterfaceOrientationMask) {
        lockedOrientation = orientation
        isLocked = true
        notifyOrientationChange()
    }

    /// Re-lock to the current orientation (updates locked orientation even if already locked)
    func lockToCurrentOrientation() {
        lockedOrientation = currentInterfaceOrientationMask
        isLocked = true
        notifyOrientationChange()
    }

    /// Unlock orientation to allow all rotations again
    func unlock() {
        guard isLocked else { return }
        isLocked = false
        lockedOrientation = nil
        notifyOrientationChange()
    }

    /// Returns the supported interface orientations.
    /// When locked, returns only the locked orientation.
    /// Otherwise: iPhone = all except upside-down, iPad = all
    var supportedOrientations: UIInterfaceOrientationMask {
        if isLocked, let locked = lockedOrientation {
            return locked
        }

        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    /// Requests an interface orientation for the foreground scene.
    /// Geometry requests are the supported iOS 16+ mechanism and can be denied
    /// by the system, so every denial stays visible in player logs.
    func request(
        _ orientation: UIInterfaceOrientationMask,
        reason: String,
        scene preferredScene: UIWindowScene? = nil
    ) {
        guard let windowScene = preferredScene ?? foregroundScene else {
            LoggingService.shared.logPlayer("[Orientation] Request skipped: no foreground scene (reason=\(reason))")
            return
        }

        notifyOrientationChange(in: windowScene)
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation)) { error in
            Task { @MainActor in
                LoggingService.shared.logPlayer(
                    "[Orientation] Request denied: mask=\(orientation.rawValue), reason=\(reason), error=\(error.localizedDescription)"
                )
            }
        }
    }

    /// Returns the foreground scene used by the app's orientation policy.
    private var foregroundScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    /// Notify the system that supported orientations have changed.
    private func notifyOrientationChange(in windowScene: UIWindowScene? = nil) {
        guard let windowScene = windowScene ?? foregroundScene else { return }

        // Tell all view controllers to re-query supported orientations
        for window in windowScene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    /// Get the current interface orientation as a mask
    var currentInterfaceOrientationMask: UIInterfaceOrientationMask {
        guard let windowScene = foregroundScene else {
            return .allButUpsideDown
        }

        let interfaceOrientation: UIInterfaceOrientation
        if #available(iOS 26.0, *) {
            interfaceOrientation = windowScene.effectiveGeometry.interfaceOrientation
        } else {
            interfaceOrientation = windowScene.interfaceOrientation
        }

        if interfaceOrientation.isLandscape {
            // Currently landscape - determine which side based on interface orientation
            switch interfaceOrientation {
            case .landscapeLeft:
                return .landscapeLeft
            case .landscapeRight:
                return .landscapeRight
            default:
                return .landscape
            }
        } else {
            return .portrait
        }
    }
}

#endif
