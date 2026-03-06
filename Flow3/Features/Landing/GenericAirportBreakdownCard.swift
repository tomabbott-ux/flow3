import SwiftUI

struct GenericAirportBreakdownCard: View {

    @ObservedObject var store: LandingStore
    @Binding var selectedRowID: String?

    var rows: [AirportDisplayRow] {
        store.displayRowsForSelectedAirport()
    }

    var sectionTitle: String {
        if store.selectedAirport == .atl {
            return "\(store.selectedAirport.rawValue) checkpoints"
        } else {
            return "\(store.selectedAirport.rawValue) terminals"
        }
    }

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {

                Text(sectionTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                VStack(spacing: 12) {
                    ForEach(rows) { row in
                        breakdownRow(row)
                    }
                }
            }
            .flowGlassCard()
            .onAppear {
                if selectedRowID == nil {
                    selectedRowID = rows.first?.id
                }
            }
        }
    }

    func breakdownRow(_ row: AirportDisplayRow) -> some View {
        let isSelected = selectedRowID == row.id

        return Button {
            selectedRowID = row.id
        } label: {
            HStack(spacing: 14) {

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(row.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }

                Spacer()

                HStack(spacing: 10) {
                    ForEach(row.metrics) { metric in
                        metricPill(metric)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? FlowBrand.accent.opacity(0.22) : Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(isSelected ? 0.18 : 0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    func metricPill(_ metric: AirportDisplayMetric) -> some View {
        VStack(spacing: 4) {
            Text(metric.minutes == nil ? "--" : "\(metric.minutes!)m")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text(metric.label)
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

private enum FlowBrand {
    static let accent = Color(hex: "8B5CF6")
}
