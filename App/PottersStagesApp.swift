import SwiftData
import SwiftUI

@main
struct PottersStagesApp: App {
    private let container = Store.makeContainer()

    var body: some Scene {
        WindowGroup {
            HomeView()
                #if DEBUG
                .task { NotesImport.runIfPresent(into: container.mainContext) }
                #endif
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1000, height: 700)
        #endif
    }
}
