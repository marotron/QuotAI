import Foundation
import QuotAICore

/// On successful refresh → band decision → cooldown → notify/email adapters.
@MainActor
enum PaceAlertOrchestrator {
    private static let lastSignatureKey = "paceAlertLastSignature"
    private static let lastDeliveredKey = "paceAlertLastDeliveredAt"
    /// Default 1 hour between identical signatures.
    static let defaultCooldown: TimeInterval = 3600

    static func handleSuccessfulRefresh(
        cursor: QuotaMeter,
        other: QuotaMeter?,
        grok: QuotaMeter,
        now: Date = Date(),
        cooldown: TimeInterval = 3600
    ) async {
        let defaults = UserDefaults.standard
        let smart = defaults.object(forKey: "useSmartPaceAlerts") as? Bool ?? true
        let thresholds = PaceAlertThresholds(
            overMaxStartPct: Double(defaults.object(forKey: "overMaxStartPct") as? Int ?? 25),
            overEmptyBeforePct: Double(defaults.object(forKey: "overEmptyBeforePct") as? Int ?? 95),
            underAfterPct: Double(defaults.object(forKey: "underAfterPct") as? Int ?? 25),
            underMinEndPct: Double(defaults.object(forKey: "underMinEndPct") as? Int ?? 95)
        )
        let legacyUnder = Double(defaults.object(forKey: "blinkUnderPercent") as? Int ?? 75) / 100
        let legacyOver = Double(defaults.object(forKey: "blinkOverPercent") as? Int ?? 130) / 100
        let blinkEnabled = defaults.bool(forKey: "blinkSignificantPace")
        let notifyEnabled = defaults.bool(forKey: "notifySignificantPace")
        let emailEnabled = defaults.bool(forKey: "emailSignificantPace")

        var inputs: [PaceAlertMeterInput] = []
        if let sample = meterInput(id: "cursor", meter: cursor, now: now) {
            inputs.append(sample)
        }
        if let other, let sample = meterInput(id: "other", meter: other, now: now) {
            inputs.append(sample)
        }
        if let sample = meterInput(id: "grok", meter: grok, now: now) {
            inputs.append(sample)
        }

        let decision = PaceAlertDecision.evaluate(
            meters: inputs,
            thresholds: thresholds,
            smart: smart,
            legacyUnder: legacyUnder,
            legacyOver: legacyOver,
            channels: PaceAlertChannels(blink: blinkEnabled, notify: notifyEnabled, email: emailEnabled)
        )

        // Blink is live in the menu bar; only gate notify/email here.
        guard decision.shouldNotify || decision.shouldEmail else { return }

        let lastSignature = defaults.string(forKey: lastSignatureKey)
        let lastDelivered = defaults.object(forKey: lastDeliveredKey) as? Date
        let deliver = PaceAlertCooldown.shouldDeliver(
            signature: decision.signature,
            now: now,
            lastSignature: lastSignature,
            lastDeliveredAt: lastDelivered,
            cooldown: cooldown
        )
        guard deliver else { return }

        let details: [PaceAlertMeterDetail] = decision.alerts.compactMap { alert in
            guard let input = inputs.first(where: { $0.id == alert.id }) else { return nil }
            return PaceAlertMeterDetail(
                name: alert.name,
                kind: alert.kind,
                percentUsed: input.percentUsed,
                elapsedPercent: input.elapsedFraction * 100
            )
        }
        let subject = AlertMessageBuilder.subject(alerts: decision.alerts)
        let body = AlertMessageBuilder.body(alerts: details)

        if decision.shouldNotify {
            await NotificationAlertService.deliver(subject: subject, body: body)
        }
        if decision.shouldEmail {
            let config = EmailAlertService.Config(
                host: defaults.string(forKey: "smtpHost") ?? "",
                port: defaults.object(forKey: "smtpPort") as? Int ?? 465,
                username: defaults.string(forKey: "smtpUsername") ?? "",
                fromAddress: defaults.string(forKey: "smtpFrom") ?? "",
                toAddress: defaults.string(forKey: "smtpTo") ?? "",
                useTLS: defaults.object(forKey: "smtpUseTLS") as? Bool ?? true
            )
            try? await EmailAlertService.send(config: config, subject: subject, body: body)
        }

        defaults.set(decision.signature, forKey: lastSignatureKey)
        defaults.set(now, forKey: lastDeliveredKey)
    }

    private static func meterInput(id: String, meter: QuotaMeter, now: Date) -> PaceAlertMeterInput? {
        guard !meter.isUnavailable,
              let pct = meter.percentUsed,
              let start = meter.periodStart,
              let end = meter.periodEnd,
              let t = PaceCalculator.elapsedFraction(periodStart: start, periodEnd: end, now: now)
        else { return nil }
        return PaceAlertMeterInput(id: id, name: meter.name, percentUsed: pct, elapsedFraction: t)
    }
}
