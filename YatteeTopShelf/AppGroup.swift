import Foundation

enum AppGroup {
    static let identifier = "group.app.vela.video.shared"
    static let enabledSectionsKey = "topShelf.enabledSections"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
