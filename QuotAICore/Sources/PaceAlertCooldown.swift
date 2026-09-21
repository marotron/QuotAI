import Foundation

/// Edge + cooldown gate so polling does not spam notify/email.
public enum PaceAlertCooldown {
    public static func shouldDeliver(
        signature: String,
        now: Date,
        lastSignature: String?,
        lastDeliveredAt: Date?,
        cooldown: TimeInterval
    ) -> Bool {
        guard !signature.isEmpty else { return false }
        if signature != lastSignature { return true }
        guard let lastDeliveredAt else { return true }
        return now.timeIntervalSince(lastDeliveredAt) >= cooldown
    }
}
