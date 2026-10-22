import AppKit
import QuotAICore
import SwiftUI

enum QuotAIAboutInfo {
    static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    static var shortCommit: String {
        Bundle.main.object(forInfoDictionaryKey: "QuotAIGitCommit") as? String ?? "—"
    }

    static var versionLine: String {
        "Version \(marketingVersion) (build \(buildNumber))"
    }

    static var commitLine: String {
        "Commit \(shortCommit)"
    }

    static let tagline = "Cursor Spending quotas in the menu bar."
    static let summary =
        "Cursor Models, Other Models, and Grok Bot — pace as rings and blinks. Data stays on this Mac."
    static let copyright = "Copyright © 2026 marotron. Licensed under MIT."
    static let githubReleasesURL = URL(string: "https://github.com/marotron/QuotAI/releases")!

    static func changelogText() -> String {
        guard
            let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
            let raw = try? String(contentsOf: url, encoding: .utf8)
        else {
            return "# Changelog\n\nChangelog file is not bundled in this build."
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct QuotAIAboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            if let icon = NSApplication.shared.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
            }

            VStack(spacing: 4) {
                Text("QuotAI")
                    .font(.title.bold())
                Text(QuotAIAboutInfo.versionLine)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(QuotAIAboutInfo.commitLine)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            VStack(spacing: 6) {
                Text(QuotAIAboutInfo.tagline)
                Text(QuotAIAboutInfo.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 340)

            VStack(spacing: 8) {
                Button("View changelog…") {
                    AboutWindowHost.shared.showChangelog()
                }

                Button("Release notes on GitHub…") {
                    NSWorkspace.shared.open(QuotAIAboutInfo.githubReleasesURL)
                }
                .buttonStyle(.link)
            }

            Text(QuotAIAboutInfo.copyright)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(28)
        .frame(width: 400)
    }
}

struct QuotAIChangelogView: View {
    private let releases = ChangelogParser.parseReleases(QuotAIAboutInfo.changelogText())

    var body: some View {
        ScrollView {
            if releases.isEmpty {
                Text(QuotAIAboutInfo.changelogText())
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            } else {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(releases) { release in
                        releaseSection(release)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 480, minHeight: 420)
    }

    @ViewBuilder
    private func releaseSection(_ release: ChangelogRelease) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(release.version) — \(release.date)")
                .font(.headline)

            ForEach(release.sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundStyle(.secondary)
                            changelogItemText(item)
                                .font(.callout)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func changelogItemText(_ item: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: item,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(item)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
