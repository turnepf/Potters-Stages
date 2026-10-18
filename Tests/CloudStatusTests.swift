import Foundation
import Testing
@testable import PottersStages

/// The More menu must name the right iCloud database: a wrong "Production" would hide that
/// pieces are still only in Development.
struct CloudStatusTests {
    private func profile(getTaskAllow: Bool) -> Data {
        Data("""
        junk-before<?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
        \t<key>Entitlements</key>
        \t<dict>
        \t\t<key>get-task-allow</key>
        \t\t<\(getTaskAllow)/>
        \t</dict>
        </dict></plist>junk-after
        """.utf8)
    }

    @Test func noProfileMeansTestFlightOrAppStore() {
        #expect(CloudEnvironment.fromProvisioningProfile(nil) == .production)
    }

    @Test func debugProfileMeansDevelopment() {
        #expect(CloudEnvironment.fromProvisioningProfile(profile(getTaskAllow: true)) == .development)
    }

    @Test func nonDebugProfileMeansProduction() {
        #expect(CloudEnvironment.fromProvisioningProfile(profile(getTaskAllow: false)) == .production)
    }

    @Test func summaryWarnsWhenCountsDiffer() {
        let same = SyncCounts(cloudPieces: 56, cloudPhotos: 74, localPieces: 56, localPhotos: 74)
        #expect(same.isInSync)
        #expect(!same.summary.contains("don't match"))

        let behind = SyncCounts(cloudPieces: 0, cloudPhotos: 0, localPieces: 56, localPhotos: 74)
        #expect(!behind.isInSync)
        #expect(behind.summary.contains("don't match"))
    }
}
