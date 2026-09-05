//
//  OrientationManager.swift
//  Vela
//
//  Coalesces scene-geometry requests and orientation restrictions.
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

    private struct Request {
        let orientation: UIInterfaceOrientationMask
        let reason: String
        let priority: RequestPriority
        weak var scene: UIWindowScene?
        let unlockWhenApplied: Bool
    }

    static let shared = OrientationManager()

    private var lockedOrientation: UIInterfaceOrientationMask?
    private(set) var isLocked = false
    private var inFlight: Request?
    private var queued: Request?
    private var requestGeneration: UInt = 0
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

    /// Starts a player presentation. UIKit cannot cancel an accepted geometry
    /// request, so a new session queues behind the transport-level request that
    /// is already draining rather than submitting an overlapping request.
    func beginPlayerSession() {
        automaticLandscapeSuppressed = false
        if inFlight == nil { queued = nil }
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
        if #available(iOS 26.0, *) { return scene.effectiveGeometry.interfaceOrientation }
        return scene.interfaceOrientation
    }

    func effectiveOrPendingOrientation(in scene: UIWindowScene) -> UIInterfaceOrientationMask {
        queued?.orientation ?? inFlight?.orientation ?? mask(for: effectiveOrientation(in: scene))
    }

    func request(
        _ orientation: UIInterfaceOrientationMask,
        reason: String,
        priority: RequestPriority = .physical,
        scene preferredScene: UIWindowScene? = nil,
        unlockWhenApplied: Bool = false
    ) {
        guard let scene = preferredScene ?? foregroundScene else {
            LoggingService.shared.logPlayer("[Orientation] Request skipped: no foreground scene (reason=\(reason))")
            return
        }
        if priority == .automatic, automaticLandscapeSuppressed { return }
        if priority == .explicit, orientation == .portrait {
            automaticLandscapeSuppressed = true
        } else if orientation.isLandscapeMask {
            automaticLandscapeSuppressed = false
        }

        let request = Request(
            orientation: orientation,
            reason: reason,
            priority: priority,
            scene: scene,
            unlockWhenApplied: unlockWhenApplied
        )
        guard inFlight != nil else {
            start(request)
            return
        }

        // Keep the newest user intent. Lower-priority automatic or physical
        // requests cannot replace an explicit request already waiting.
        if let queued, queued.priority.rawValue > priority.rawValue { return }
        self.queued = request
    }

    private func start(_ request: Request) {
        guard let scene = request.scene else {
            finish(request, succeeded: false)
            return
        }
        inFlight = request
        requestGeneration &+= 1
        let generation = requestGeneration
        notifyOrientationChange(in: scene)
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: request.orientation)) { [weak self] error in
            Task { @MainActor in
                guard let self,
                      generation == self.requestGeneration else { return }
                LoggingService.shared.logPlayer(
                    "[Orientation] Request denied: mask=\(request.orientation.rawValue), reason=\(request.reason), error=\(error.localizedDescription)"
                )
                self.finish(request, succeeded: false)
            }
        }
        observe(request, generation: generation)
    }

    private func observe(_ request: Request, generation: UInt) {
        Task { @MainActor [weak self, weak scene = request.scene] in
            for _ in 0..<40 {
                guard let self, let scene,
                      generation == self.requestGeneration else { return }
                if request.orientation.contains(self.mask(for: self.effectiveOrientation(in: scene))) {
                    self.finish(request, succeeded: true)
                    return
                }
                try? await Task.sleep(for: .milliseconds(25))
            }
            guard let self,
                  generation == self.requestGeneration else { return }
            LoggingService.shared.logPlayer("[Orientation] Request timed out: mask=\(request.orientation.rawValue)")
            self.finish(request, succeeded: false)
        }
    }

    private func finish(_ request: Request, succeeded _: Bool) {
        guard inFlight != nil else { return }
        inFlight = nil
        if request.unlockWhenApplied { unlock() }
        if let next = queued {
            queued = nil
            start(next)
        }
    }

    private var foregroundScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    private func notifyOrientationChange(in scene: UIWindowScene? = nil) {
        guard let scene = scene ?? foregroundScene else { return }
        for window in scene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    var currentInterfaceOrientationMask: UIInterfaceOrientationMask {
        guard let scene = foregroundScene else { return .allButUpsideDown }
        return mask(for: effectiveOrientation(in: scene))
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

private extension UIInterfaceOrientationMask {
    var isLandscapeMask: Bool {
        self == .landscape || self == .landscapeLeft || self == .landscapeRight
    }
}

#endif
