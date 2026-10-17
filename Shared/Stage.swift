import SwiftUI

/// The five stages a piece moves through, in order.
nonisolated enum Stage: String, CaseIterable, Identifiable {
    case idea
    case leatherHard
    case greenware
    case bisqueware
    case finished

    var id: String { rawValue }

    var name: String {
        switch self {
        case .idea: "Idea"
        case .leatherHard: "Leather Hard"
        case .greenware: "Greenware"
        case .bisqueware: "Bisqueware"
        case .finished: "Finished"
        }
    }

    /// One line explaining what the stage means, shown beside stage pickers.
    var summary: String {
        switch self {
        case .idea: "Inspiration saved for later. Nothing made yet."
        case .leatherHard: "Firm but still damp. Time to trim, carve and attach handles."
        case .greenware: "Bone dry and fragile, waiting for the bisque firing."
        case .bisqueware: "Fired once: hard and porous. Ready to glaze, or glazed and waiting on the glaze firing."
        case .finished: "Glaze-fired and done."
        }
    }

    var symbol: String {
        switch self {
        case .idea: "lightbulb"
        case .leatherHard: "hand.raised"
        case .greenware: "leaf"
        case .bisqueware: "flame"
        case .finished: "checkmark.seal"
        }
    }

    /// The subtle color tag used everywhere this stage appears.
    var color: Color {
        switch self {
        case .idea: .yellow
        case .leatherHard: .brown
        case .greenware: .green
        case .bisqueware: .orange
        case .finished: .blue
        }
    }

    /// Position in the sequence: Idea is 0, Finished is 4.
    var order: Int { Stage.allCases.firstIndex(of: self)! }

    /// The stage after this one, or nil when Finished.
    var next: Stage? {
        let all = Stage.allCases
        return order + 1 < all.count ? all[order + 1] : nil
    }
}

/// A small colored capsule showing a stage name.
struct StageTag: View {
    let stage: Stage

    var body: some View {
        Label(stage.name, systemImage: stage.symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(stage.color.opacity(0.22), in: .capsule)
            .overlay(Capsule().strokeBorder(stage.color.opacity(0.45)))
    }
}

/// A form section with a stage menu and the chosen stage's description underneath.
struct StagePickerSection: View {
    @Binding var stage: Stage

    var body: some View {
        Section {
            Picker("Stage", selection: $stage) {
                ForEach(Stage.allCases) { stage in
                    Label(stage.name, systemImage: stage.symbol).tag(stage)
                }
            }
        } footer: {
            Text(stage.summary)
        }
    }
}
