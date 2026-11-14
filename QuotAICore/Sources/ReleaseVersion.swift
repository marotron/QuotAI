import Foundation

/// Apple marketing versions remain numeric; RC identity is a separate bundle field.
public enum ReleaseVersion {
    public static func label(marketing: String, candidate: Int) -> String {
        candidate > 0 ? "\(marketing)-rc.\(candidate)" : marketing
    }
}
