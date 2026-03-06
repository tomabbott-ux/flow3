import SwiftUI

struct GenericAirportBreakdownCard: View {

    @ObservedObject var store: LandingStore
    @Binding var selectedRowID: String?

    private var rows: [AirportDisplayRow] {
        store.displayRowsForSelectedAirport()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("\(store.selectedAirport.rawValue) checkpoints")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                ForEach(rows) { row in
                    rowView(row)
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

    private func rowView(_ row: AirportDisplayRow) -> some View {
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
                    .fill(isSelected ? Color.white.opacity(0.16) : Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(isSelected ? 0.18 : 0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func metricPill(_ metric: AirportMetric) -> some View {
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
