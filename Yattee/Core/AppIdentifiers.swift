import Foundation

/// Centralized app identifiers - single source of truth for all app-wide identifiers.
enum AppIdentifiers {
    // MARK: - Base Identifier

    static let bundleIdentifier = "app.vela.video"
    static let urlScheme = "vela"

    // MARK: - iCloud

    static var iCloudContainer: String {
        "iCloud.\(bundleIdentifier)"
    }

    // MARK: - Background Tasks

    static var backgroundFeedRefresh: String {
        "\(bundleIdentifier).feedRefresh"
    }

    // MARK: - User Activities (Handoff)

    static var handoffActivityType: String {
        "\(bundleIdentifier).activity"
    }

    // MARK: - URL Sessions

    static let downloadSession = "app.vela.video.downloads"

    // MARK: - Logging

    static var logSubsystem: String {
        bundleIdentifier
    }
}
