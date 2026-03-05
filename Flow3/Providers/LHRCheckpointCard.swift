import SwiftUI

struct LHRCheckpointCard: View {

    @ObservedObject var store: LandingStore
    @Binding var selectedTerminal: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("LHR terminals")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                terminalRow(2)
                terminalRow(3)
                terminalRow(4)
                terminal5Row()
            }
        }
        .lhrGlassCard()
        .onAppear {
            if selectedTerminal == nil {
                selectedTerminal = 5
            }
        }
    }

    // MARK: - Rows

    private func terminalRow(_ terminal: Int) -> some View {
        let minutes = store.lhrMinutes(terminal: terminal, category: .general)
        let isSelected = (selectedTerminal ?? 5) == terminal

        return Button {
            selectedTerminal = terminal
        } label: {
            HStack(spacing: 14) {

                VStack(alignment: .leading, spacing: 4) {
                    Text("Terminal \(terminal)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Security")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }

                Spacer()

                waitPill(value: minutes)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? LHRBrand.accent.opacity(0.22) : Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(isSelected ? 0.18 : 0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func terminal5Row() -> some View {
        // North -> .general, South -> .precheck
        let north = store.lhrMinutes(terminal: 5, category: .general)
        let south = store.lhrMinutes(terminal: 5, category: .precheck)
        let isSelected = (selectedTerminal ?? 5) == 5

        return Button {
            selectedTerminal = 5
        } label: {
            HStack(spacing: 14) {

                VStack(alignment: .leading, spacing: 4) {
                    Text("Terminal 5")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Security")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }

                Spacer()

                HStack(spacing: 10) {
                    miniPill(title: "North", value: north)
                    miniPill(title: "South", value: south)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? LHRBrand.accent.opacity(0.22) : Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(isSelected ? 0.18 : 0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pills

    private func waitPill(value: Int?) -> some View {
        VStack(spacing: 4) {
            Text(value == nil ? "--" : "\(value!)m")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text("Wait")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(width: 88, height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private func miniPill(title: String, value: Int?) -> some View {
        VStack(spacing: 4) {
            Text(value == nil ? "--" : "\(value!)m")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(width: 78, height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

// MARK: - Local styling (kept in this file)

private enum LHRBrand {
    static let accent = Color(hex: "8B5CF6")
}

private extension View {
    func lhrGlassCard() -> some View {
        self
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        case 8:
            (a, r, g, b) = ((int >> 24) & 255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
