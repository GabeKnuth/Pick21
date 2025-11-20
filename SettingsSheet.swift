import SwiftUI

struct SettingsSheet: View {
    @Binding var hapticsEnabled: Bool
    @Binding var deckCount: Int
    let clearAction: () -> Void

    @State private var confirmClear = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Feedback") {
                    Toggle("Haptics", isOn: $hapticsEnabled)
                }

                Section {
                    Button(role: .destructive) {
                        confirmClear = true
                    } label: {
                        Label("Clear High Scores", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Settings")
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
            .alert("Clear all high scores?",
                   isPresented: $confirmClear) {
                Button("Clear High Scores", role: .destructive) {
                    clearAction()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }
}
