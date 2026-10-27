import CodexBarCore
import Foundation
import Testing
@testable import CodexBarCLI

struct DashboardWindowDurationTests {
    @Test
    func `dashboard window omits an unknown window duration`() throws {
        let payload = ProviderPayload(
            provider: .claude,
            account: nil,
            version: nil,
            source: "web",
            status: nil,
            usage: UsageSnapshot(
                primary: RateWindow(
                    usedPercent: 12,
                    windowMinutes: nil,
                    resetsAt: nil,
                    resetDescription: nil),
                secondary: nil,
                tertiary: nil,
                updatedAt: Date(timeIntervalSince1970: 0)),
            credits: nil,
            antigravityPlanInfo: nil,
            openaiDashboard: nil,
            error: nil)

        let snapshot = DashboardSnapshotBuilder.makeSnapshot(
            usagePayloads: [payload],
            costPayloads: [],
            config: CodexBarConfig(providers: [ProviderConfig(id: .claude, enabled: true)]),
            identityMode: .redacted,
            generatedAt: Date(timeIntervalSince1970: 0),
            refreshInterval: 60,
            codexBarVersion: nil)
        let object = try self.jsonObject(snapshot)
        let provider = try #require((object["providers"] as? [[String: Any]])?.first)
        let windows = try #require(provider["windows"] as? [[String: Any]])

        #expect(windows.count == 1)
        // The key is absent rather than null, and never a default guessed from the kind or the label.
        #expect(windows[0]["windowMinutes"] == nil)
    }

    @Test
    func `dashboard window keeps a provider reported nonstandard window duration`() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload = ProviderPayload(
            provider: .claude,
            account: nil,
            version: nil,
            source: "web",
            status: nil,
            usage: UsageSnapshot(
                primary: nil,
                secondary: nil,
                tertiary: nil,
                extraRateWindows: [NamedRateWindow(
                    id: "claude-scoped-3h",
                    title: "Three-hour window",
                    window: RateWindow(
                        usedPercent: 12,
                        windowMinutes: 180,
                        resetsAt: now,
                        resetDescription: nil))],
                updatedAt: now),
            credits: nil,
            antigravityPlanInfo: nil,
            openaiDashboard: nil,
            error: nil)

        let snapshot = DashboardSnapshotBuilder.makeSnapshot(
            usagePayloads: [payload],
            costPayloads: [],
            config: CodexBarConfig(providers: [ProviderConfig(id: .claude, enabled: true)]),
            identityMode: .redacted,
            generatedAt: now,
            refreshInterval: 60,
            codexBarVersion: nil)
        let object = try self.jsonObject(snapshot)
        let provider = try #require((object["providers"] as? [[String: Any]])?.first)
        let windows = try #require(provider["windows"] as? [[String: Any]])

        // The reported duration is copied verbatim, so a client never has to map a lane onto a fixed window.
        #expect(windows.count == 1)
        #expect(windows[0]["kind"] as? String == "claude-scoped-3h")
        #expect(windows[0]["windowMinutes"] as? Int == 180)
    }

    private func jsonObject(_ payload: some Encodable) throws -> [String: Any] {
        let json = try #require(CodexBarCLI.encodeJSON(payload, pretty: false))
        let data = try #require(json.data(using: .utf8))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
