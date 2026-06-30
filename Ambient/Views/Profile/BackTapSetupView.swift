import SwiftUI

struct BackTapSetupView: View {
    private let steps: [(icon: String, title: String, detail: String)] = [
        (
            "gear",
            "Open Settings",
            "Go to the Settings app on your iPhone."
        ),
        (
            "figure.walk",
            "Accessibility",
            "Scroll down and tap Accessibility."
        ),
        (
            "hand.tap",
            "Touch → Back Tap",
            "Tap Touch, then scroll down and tap Back Tap."
        ),
        (
            "hand.point.up.left",
            "Choose Double Tap or Triple Tap",
            "Select whichever gesture you prefer — Double Tap is easiest."
        ),
        (
            "list.bullet",
            "Select Shortcut",
            "Scroll to the Shortcuts section at the bottom and choose Search Nearby (Ambient Social)."
        ),
        (
            "checkmark.circle",
            "Done",
            "Double-tap or triple-tap the back of your iPhone to instantly trigger a nearby scan — even from the lock screen."
        ),
    ]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Back Tap lets you trigger Ambient Social's nearby scan by tapping the back of your iPhone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("This is optional — the app works fine without it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Setup Steps") {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 34, height: 34)
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.tint)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.title)
                                .font(.headline)
                            Text(step.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 6)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Label(
                    "Requires iOS 14.0 or later and a compatible iPhone (6s or newer).",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Back Tap Setup")
        .navigationBarTitleDisplayMode(.inline)
    }
}
