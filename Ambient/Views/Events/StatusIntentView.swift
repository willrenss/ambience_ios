import SwiftUI

struct StatusIntentView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var statusText = ""
    @State private var isBusy = false
    @FocusState private var focused: Bool

    var onGetIntoRadar: (String) async -> Void

    private let maxLength = 100
    private let teal = Color(red: 0.22, green: 0.44, blue: 0.47)

    private var trimmed: String {
        statusText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Title
            Text("What Are You Up to?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

            // Text input
            ZStack(alignment: .bottomTrailing) {
                ZStack(alignment: .topLeading) {
                    if statusText.isEmpty {
                        Text("Share what you're doing, looking for, or open to talk about...")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(.placeholderText))
                            .padding(.top, 12)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $statusText)
                        .font(.system(size: 15))
                        .frame(minHeight: 90, maxHeight: 110)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .focused($focused)
                        .onChange(of: statusText) { _, new in
                            if new.count > maxLength {
                                statusText = String(new.prefix(maxLength))
                            }
                        }
                }
                .padding(.bottom, 20)

                Text("\(statusText.count)/\(maxLength)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)
                    .padding(.trailing, 2)
            }
            .padding(14)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(hex: 0x8B3A2A).opacity(0.35), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer().frame(height: 24)

            // Continue button
            Button {
                guard !trimmed.isEmpty, !isBusy else { return }
                isBusy = true
                Task {
                    await onGetIntoRadar(trimmed)
                    isBusy = false
                    dismiss()
                }
            } label: {
                Group {
                    if isBusy {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(trimmed.isEmpty ? Color(.systemGray2) : .white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    trimmed.isEmpty ? Color(.systemGray4) : teal,
                    in: Capsule()
                )
                .background(
                    Capsule().fill(.black).offset(y: 4)
                )
            }
            .disabled(trimmed.isEmpty || isBusy)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .onTapGesture { focused = false }
    }
}

struct StatusPatchBody: Encodable {
    let status: String
}
