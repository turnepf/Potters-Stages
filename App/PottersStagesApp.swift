import SwiftData
import SwiftUI

@main
struct PottersStagesApp: App {
    private let container = ScreenshotMode.container ?? Store.makeContainer()

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(container)
        #if os(macOS)
        // Screenshot mode opens at 1440×900, one of the App Store's Mac screenshot sizes.
        .defaultSize(width: ScreenshotMode.isOn ? 1440 : 1000, height: ScreenshotMode.isOn ? 900 : 700)
        #endif
    }
}

/// For App Store screenshots: launch a debug build with `-screenshotBackup <path to backup>`
/// to show that backup's pieces from a throwaway in-memory store, with no iCloud and no
/// Development banner. Debug builds only; never in TestFlight or App Store builds.
enum ScreenshotMode {
    #if DEBUG
    static let backupPath = UserDefaults.standard.string(forKey: "screenshotBackup")
    #else
    static let backupPath: String? = nil
    #endif

    static var isOn: Bool { backupPath != nil }

    static let container: ModelContainer? = {
        guard let backupPath else { return nil }
        let container = Store.makeContainer(inMemory: true)
        do {
            let backup = try Backup.decode(Data(contentsOf: URL(fileURLWithPath: backupPath)))
            try backup.restore(into: container.mainContext)
        } catch {
            print("Screenshot mode: couldn't load \(backupPath): \(error)")
        }
        return container
    }()
}
