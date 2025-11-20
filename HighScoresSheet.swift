import SwiftUI

struct HighScoresSheet: View {
    let entries: [HighScoreEntry]
    @Environment(\.dismiss) private var dismiss
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if entries.isEmpty {
                        ContentUnavailableView("No High Scores", systemImage: "trophy", description: Text("Play a game to set your first high score."))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        HighScoresView(
                            entries: entries,
                            baseFontSize: 20,
                            rowVPadding: 0.5,
                            headerSpacing: 3
                        )
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle("High Scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
        }
    }
}
