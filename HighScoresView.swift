import SwiftUI

struct HighScoresView: View {
    let entries: [HighScoreEntry]
    var baseFontSize: CGFloat = 20
    var rowVPadding: CGFloat = 4
    var headerSpacing: CGFloat = 6

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none
        return df
    }()

    var body: some View {
        let maxRows = 10
        let shown = Array(entries.prefix(maxRows))
        let placeholderCount = max(0, maxRows - shown.count)

        VStack(alignment: .leading, spacing: headerSpacing) {
            if entries.isEmpty {
                Text("No scores yet.")
                    .font(.system(size: baseFontSize, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: max(0, rowVPadding)) {
                    HStack(spacing: 12) {
                        Text("Rank")
                            .font(.system(size: baseFontSize, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Score")
                            .font(.system(size: baseFontSize, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Date")
                            .font(.system(size: baseFontSize, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ForEach(Array(shown.enumerated()), id: \.element.id) { idx, entry in
                        rowView(rank: idx + 1,
                                scoreText: entry.score.formatted(),
                                dateText: dateFormatter.string(from: entry.date),
                                isPlaceholder: false)
                    }

                    ForEach(0..<placeholderCount, id: \.self) { idx in
                        rowView(rank: shown.count + idx + 1,
                                scoreText: "—",
                                dateText: "—",
                                isPlaceholder: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func rowView(rank: Int, scoreText: String, dateText: String, isPlaceholder: Bool) -> some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.system(size: baseFontSize, weight: .regular, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(scoreText)
                .font(.system(size: baseFontSize, weight: .regular, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(dateText)
                .font(.system(size: baseFontSize, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, max(0, rowVPadding))
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground).opacity(isPlaceholder ? 0.45 : 0.8))
        )
        .opacity(isPlaceholder ? 0.7 : 1.0)
    }
}
