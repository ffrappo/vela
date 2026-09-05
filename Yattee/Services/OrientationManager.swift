//
//  OrientationManager.swift
//  Vela
//
//  Serializes scene-geometry requests and orientation restrictions.
//

#if os(iOS)

import UIKit

@MainActor
final class OrientationManager {
    enum RequestPriority: Int, Sendable {
        case automatic = 0
        case physical = 1
        case explicit = 2
        case dismissal = 3
    }

    static let shared = OrientationManager()

    private var lockedOrientation: UIInterfaceOrientationMask?
    private(set) var isLocked = false
    private var requestGeneration: UInt = 0
    private var pendingOrientation: UIInterfaceOrientationMask?
    private var pendingPriority: RequestPriority?
    private var automaticLandscapeSuppressed = false

    private init() {}

    func lock() {
        guard UIDevice.current.userInterfaceIdiom == .phone, !isLocked else { return }
        lockedOrientation = currentInterfaceOrientationMask
        isLocked = true
        notifyOrientationChange()
    }

    func lock(to orientation: UIInterfaceOrientationMask) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        lockedOrientation = orientation
        isLocked = true
        notifyOrientationChange()
    }

    func lockToCurrentOrientation() {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        lockedOrientation = currentInterfaceOrientationMask
        isLocked = true
        notifyOrientationChange()
    }

    func unlock() {
        guard isLocked else { return }
        isLocked = false
        lockedOrientation = nil
        notifyOrientationChange()
    }

    func resetAutomaticLandscapeSuppression() {
        automaticLandscapeSuppressed = false
    }

    var supportedOrientations: UIInterfaceOrientationMask {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return .all }
        if isLocked, let lockedOrientation { return lockedOrientation }
        return .allButUpsideDown
    }

    func effectiveOrientation(in scene: UIWindowScene) -> UIInterfaceOrientation {
        if #available(iOS 26.0, *) {
            return scene.effectiveGeometry.interfaceOrientation
        }
        return scene.interfaceOrientation
    }

    /// Returns the resolved orientation together with an in-flight explicit
    /// target so repeated fullscreen taps reverse the user's latest intent.
    func effectiveOrPendingOrientation(in scene: UIWindowScene) -> UIInterfaceOrientationMask {
        pendingOrientation ?? mask(for: effectiveOrientation(in: scene))
    }

    func request(
        _ orientation: UIInterfaceOrientationMask,
        reason: String,
        priority: RequestPriority = .physical,
        scene preferredScene: UIWindowScene? = nil,
        unlockWhenApplied: Bool = false
    ) {
        guard let windowScene = preferredScene ?? foregroundScene else {
            LoggingService.shared.logPlayer("[Orientation] Request skipped: no foreground scene (reason=\(reason))")
            return
        }

        if priority == .automatic, automaticLandscapeSuppressed {
            return
        }
        if priority == .explicit, orientation == .portrait {
            automaticLandscapeSuppressed = true
        } else if orientation == .landscape || orientation == .landscapeLeft || orientation == .landscapeRight {
            automaticLandscapeSuppressed = false
        }

        if let pendingPriority, pendingPriority.rawValue > priority.rawValue {
            LoggingService.shared.logPlayer(
                "[Orientation] Request ignored behind higher priority intent: reason=\(reason)"
            )
            return
        }

        requestGeneration &+= 1
        let generation = requestGeneration
        pendingOrientation = orientation
        pendingPriority = priority
        notifyOrientationChange(in: windowScene)

        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation)) { [weak self, weak windowScene] error in
            Task { @MainActor in
                guard let self, generation == self.requestGeneration else { return }
                self.pendingOrientation = nil
                self.pendingPriority = nil
                LoggingService.shared.logPlayer(
                    "[Orientation] Request denied: mask=\(orientation.rawValue), reason=\(reason), error=\(error.localizedDescription)"
                )
                if unlockWhenApplied { self.unlock() }
                windowScene?.windows.forEach {
                    $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                }
            }
        }

        observeApplied(
            orientation,
            generation: generation,
            scene: windowScene,
            unlockWhenApplied: unlockWhenApplied
        )
    }

    private func observeApplied(
        _ target: UIInterfaceOrientationMask,
        generation: UInt,
        scene: UIWindowScene,
        unlockWhenApplied: Bool
    ) {
        Task { @MainActor [weak self, weak scene] in
            for _ in 0..<40 {
                guard let self, let scene, generation == self.requestGeneration else { return }
                if target.contains(self.mask(for: self.effectiveOrientation(in: scene))) {
                    self.pendingOrientation = nil
                    self.pendingPriority = nil
                    if unlockWhenApplied { self.unlock() }
                    return
                }
                try? await Task.sleep(for: .milliseconds(25))
            }
            guard let self, generation == self.requestGeneration else { return }
            LoggingService.shared.logPlayer(
                "[Orientation] Request timed out: mask=\(target.rawValue)"
            )
            self.pendingOrientation = nil
            self.pendingPriority = nil
            if unlockWhenApplied { self.unlock() }
        }
    }

    private var foregroundScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    private func notifyOrientationChange(in windowScene: UIWindowScene? = nil) {
        guard let windowScene = windowScene ?? foregroundScene else { return }
        for window in windowScene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    var currentInterfaceOrientationMask: UIInterfaceOrientationMask {
        guard let windowScene = foregroundScene else { return .allButUpsideDown }
        return mask(for: effectiveOrientation(in: windowScene))
    }

    private func mask(for orientation: UIInterfaceOrientation) -> UIInterfaceOrientationMask {
        switch orientation {
        case .portrait: .portrait
        case .portraitUpsideDown: .portraitUpsideDown
        case .landscapeLeft: .landscapeLeft
        case .landscapeRight: .landscapeRight
        default: .allButUpsideDown
        }
    }
}

#endif
