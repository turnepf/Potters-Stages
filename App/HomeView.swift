import SwiftData
import SwiftUI

/// The three views of the collection.
enum StageFilter: String, CaseIterable, Identifiable {
    case inProgress
    case ideas
    case done

    var id: String { rawValue }

    var name: String {
        switch self {
        case .inProgress: "In Progress"
        case .ideas: "Ideas"
        case .done: "Done"
        }
    }

    var symbol: String {
        switch self {
        case .inProgress: "hourglass"
        case .ideas: Stage.idea.symbol
        case .done: Stage.finished.symbol
        }
    }

    var color: Color {
        switch self {
        case .inProgress: Stage.greenware.color
        case .ideas: Stage.idea.color
        case .done: Stage.finished.color
        }
    }

    func includes(_ stage: Stage) -> Bool {
        switch self {
        case .inProgress: stage != .idea && stage != .finished
        case .ideas: stage == .idea
        case .done: stage == .finished
        }
    }
}

/// Stack navigation on iPhone; sidebar + grid on iPad and Mac.
struct HomeView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @State private var filter: StageFilter = .inProgress
    @State private var path: [Piece] = []
    @State private var searchText = ""
    @State private var isAdding = false

    var body: some View {
        #if os(iOS)
        if sizeClass == .compact {
            NavigationStack(path: $path) {
                grid
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        // Always-visible switch in place of the title.
                        ToolbarItem(placement: .principal) {
                            Picker("Show", selection: $filter) {
                                ForEach(StageFilter.allCases) { Text($0.name).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .fixedSize()
                        }
                    }
            }
        } else {
            splitView
        }
        #else
        splitView
        #endif
    }

    private var splitView: some View {
        NavigationSplitView {
            List(StageFilter.allCases, selection: sidebarSelection) { filter in
                Label {
                    Text(filter.name)
                } icon: {
                    Image(systemName: filter.symbol)
                        .foregroundStyle(filter.color)
                }
                .tag(filter)
            }
            .navigationTitle("Potter's Stages")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            #endif
        } detail: {
            NavigationStack(path: $path) {
                grid
            }
        }
    }

    private var grid: some View {
        PieceGrid(filter: filter, searchText: searchText)
            .navigationTitle(filter.name)
            .searchable(text: $searchText, prompt: "Search titles and notes")
            .navigationDestination(for: Piece.self) { piece in
                PieceDetailView(piece: piece)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Piece", systemImage: "plus") { isAdding = true }
                        .keyboardShortcut("n")
                }
            }
            .modifier(MoreMenu())
            .sheet(isPresented: $isAdding) {
                PieceEditor(piece: nil)
            }
            .onChange(of: filter) { path = [] }
    }

    /// The sidebar List needs an optional selection; never let it become empty.
    private var sidebarSelection: Binding<StageFilter?> {
        Binding(get: { filter }, set: { if let new = $0 { filter = new } })
    }
}
