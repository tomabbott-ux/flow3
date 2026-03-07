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
            if metric.minutes == 0 {
                HStack(spacing: 6) {
                    LivePulseDot()

                    Text("No wait")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Text(metric.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else if metric.minutes == nil {
                Text("Open")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)

                Text(metric.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text(metricPrimaryText(metric))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)

                Text(metricSecondaryText(metric))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
            }
        }
        .frame(width: 92, height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            metric.minutes == 0 || metric.minutes == nil
                            ? Color.green.opacity(0.28)
                            : Color.white.opacity(0.10),
                            lineWidth: 1
                        )
                )
        )
    }

    private func metricPrimaryText(_ metric: AirportMetric) -> String {
        guard let minutes = metric.minutes else { return "Open" }
        return "\(minutes)m"
    }

    private func metricSecondaryText(_ metric: AirportMetric) -> String {
        return metric.label
    }
}
