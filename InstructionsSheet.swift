import SwiftUI

struct InstructionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {

                    Group {
                        Text("Goal")
                            .font(.title3.weight(.semibold))
                        Text("Build five blackjack-style columns whose combined effective total is as close to 21 as possible. Hitting exactly 105 (21 x 5 columns) awards a massive bonus.")
                    }

                    Divider().opacity(0.25)

                    Group {
                        Text("How to Play")
                            .font(.title3.weight(.semibold))
                        VStack(alignment: .leading, spacing: 8) {
                            bullet("You are dealt one card at a time. Tap a column to place the current card.")
                            bullet("Aces can count as 1 or 11 (soft hands). Face cards count as 10.")
                            bullet("If a column exceeds 21, the round immediately ends as a bust.")
                            bullet("A column locks at a hard 21 (no Ace counted as 11), or with a Five‑Card Charlie (5 cards totaling ≤ 21).")
                            bullet("Locked columns cannot receive more cards.")
                            bullet("You have one Pass per round to discard the current card and draw the next.")
                        }
                    }

                    Divider().opacity(0.25)

                    Group {
                        Text("Timer & Scoring")
                            .font(.title3.weight(.semibold))
                        VStack(alignment: .leading, spacing: 8) {
                            bullet("Each round has a countdown timer. Faster finishes score more.")
                            bullet("Your round score = remaining time × a multiplier based on your board total.")
                            Text("Multipliers").font(.headline)
                            multiplierList
                            bullet("If any column is busted, the round score is 0.")
                            bullet("If the board total reaches 105 at any time, the round ends immediately with a perfect‑board bonus.")
                        }
                    }

                    Divider().opacity(0.25)

                    Group {
                        Text("Between Rounds")
                            .font(.title3.weight(.semibold))
                        VStack(alignment: .leading, spacing: 8) {
                            bullet("There are three rounds per game.")
                            bullet("Your total score is the sum of the three round scores.")
                            bullet("Set a new high score to see it saved in High Scores.")
                        }
                    }

                    Divider().opacity(0.25)

                    Group {
                        Text("Tips")
                            .font(.title3.weight(.semibold))
                        VStack(alignment: .leading, spacing: 8) {
                            bullet("Use soft hands to absorb higher cards without busting, then convert to hard 21 when safe.")
                            bullet("A Five‑Card Charlie locks the column at an effective 21 — great when you can build small cards.")
                            bullet("Save your Pass for a dangerous card when your board is fragile.")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle("How to Play")
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

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").bold()
            Text(text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var multiplierList: some View {
        VStack(alignment: .leading, spacing: 6) {
            multiplierRow("105", "× 1000")
            multiplierRow("104", "× 500")
            multiplierRow("103", "× 400")
            multiplierRow("102", "× 300")
            multiplierRow("101", "× 250")
            multiplierRow("100", "× 200")
            multiplierRow("99",  "× 150")
            multiplierRow("98",  "× 100")
            multiplierRow("97",  "× 50")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground).opacity(0.9))
        )
    }

    private func multiplierRow(_ total: String, _ mult: String) -> some View {
        HStack {
            Text(total).font(.body.weight(.semibold)).monospacedDigit()
            Spacer()
            Text(mult).font(.body).monospacedDigit()
        }
    }
}
