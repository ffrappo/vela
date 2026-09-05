//
//  PlayerOrientationPolicy.swift
//  Vela
//
//  Pure policy for automatic player orientation decisions.
//

import Foundation

#if os(iOS)

enum PlayerInterfaceOrientation: Equatable, Sendable {
    case portrait
    case landscape
}

enum PlayerOrientationAction: Equatable, Sendable {
    case none
    case requestLandscape
}

struct PlayerOrientationContext: Equatable, Sendable {
    let isPhone: Bool
    let isPlayerExpanded: Bool
    let isPiPActive: Bool
    let rotatesToMatchAspectRatio: Bool
    let interfaceOrientation: PlayerInterfaceOrientation
    let videoAspectRatio: Double?
}

enum PlayerOrientationPolicy {
    /// Wide videos may enter landscape automatically. Once the player is in
    /// landscape, loading, EOF, and video handoffs never create a portrait
    /// action. Portrait is reserved for an explicit fullscreen exit or for
    /// dismissing the player back to browsing.
    static func action(for context: PlayerOrientationContext) -> PlayerOrientationAction {
        guard context.isPhone,
              context.isPlayerExpanded,
              !context.isPiPActive,
              context.rotatesToMatchAspectRatio,
              context.interfaceOrientation == .portrait,
              let aspectRatio = context.videoAspectRatio,
              aspectRatio > 1 else {
            return .none
        }

        return .requestLandscape
    }
}

#endif
