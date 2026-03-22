import Foundation
import SwiftUI

struct AirportMetric: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let minutes: Int?
}

typealias AirportDisplayMetric = AirportMetric

struct AirportDisplayRow: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let metrics: [AirportMetric]
    let observedAt: Date?
    let isClosed: Bool
    let isLive: Bool
}

extension LandingStore {

    func displayRowsForSelectedAirport() -> [AirportDisplayRow] {

        let rows = allWaitTimes()
            .filter { $0.airport == selectedAirport }

        switch selectedAirport {

        case .atl, .ist, .slc, .iah, .ham, .dus, .edi, .str, .bru,
             .arn, .got, .osl, .doh, .zrh, .hel,
             .yvr, .yyc, .den, .dfw, .hou, .mco, .pit, .phx,
             .phl, .san, .las, .bos, .sea, .mia, .sfo,
             .bna, .tpa, .dtw, .clt, .ewr, .bwi, .cle, .dca, .pdx,
             .icn, .mad, .ber, .bcn,
             .pmi, .agp, .alc, .svq, .bio, .ibz, .vlc, .tfs, .lpa:
            return namedCheckpointRows(from: rows)

        case .jfk, .lhr, .lga, .cph, .yyz,
             .ams, .cdg, .dxb, .sin, .fra,
             .lax, .ord, .fco, .hnd, .syd, .msp:
            return terminalDisplayRows(from: rows)
        }
    }

    private func namedCheckpointRows(from rows: [WaitTimeEstimate]) -> [AirportDisplayRow] {

        let grouped = Dictionary(grouping: rows) { row in
            let checkpoint = row.checkpointName ?? "Security"
            let area = row.areaName ?? ""
            return "\(checkpoint)|\(area)"
        }

        var displayRows = grouped
            .map { key, items in

                let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)

                let title = parts.first ?? "Security"
                let subtitle = parts.count > 1 ? parts[1] : ""
                let observedAt = items.map(\.observedAt).max()
                let isClosed = items.allSatisfy(\.isClosed)
                let isLive = items.contains { $0.sourceType == .live }

                let general = items.first(where: { $0.queueType == .general && !$0.isClosed })?.minutes
                let precheck = items.first(where: { $0.queueType == .precheck && !$0.isClosed })?.minutes

                let metrics = metricsForRow(
                    general: general,
                    precheck: precheck,
                    items: items,
                    isClosed: isClosed
                )

                return AirportDisplayRow(
                    id: key,
                    title: title,
                    subtitle: subtitle,
                    metrics: metrics,
                    observedAt: observedAt,
                    isClosed: isClosed,
                    isLive: isLive
                )
            }

        if selectedAirport == .slc,
           let observedAt = rows.map(\.observedAt).max() {

            displayRows.append(
                AirportDisplayRow(
                    id: "SLC-PRECHECK-AVAILABLE",
                    title: "PreCheck",
                    subtitle: "Available",
                    metrics: [
                        AirportMetric(label: "PreCheck", minutes: nil)
                    ],
                    observedAt: observedAt,
                    isClosed: false,
                    isLive: rows.contains { $0.sourceType == .live }
                )
            )
        }

        return displayRows
            .sorted { lhs, rhs in
                if lhs.id == "SLC-PRECHECK-AVAILABLE" { return false }
                if rhs.id == "SLC-PRECHECK-AVAILABLE" { return true }

                if lhs.title == rhs.title {
                    return lhs.subtitle < rhs.subtitle
                }

                return lhs.title < rhs.title
            }
            .uniqued(by: { $0.title + "|" + $0.subtitle })
    }

    private func terminalDisplayRows(from rows: [WaitTimeEstimate]) -> [AirportDisplayRow] {

        let cleanedRows = rows.compactMap { row -> WaitTimeEstimate? in

            if selectedAirport == .lax, row.terminal == 0 {
                return WaitTimeEstimate(
                    airport: row.airport,
                    terminal: 999,
                    queueType: row.queueType,
                    minutes: row.minutes,
                    observedAt: row.observedAt,
                    checkpointName: "Tom Bradley International Terminal",
                    areaName: row.areaName,
                    sourceType: row.sourceType,
                    isClosed: row.isClosed
                )
            }

            return row
        }

        let grouped = Dictionary(grouping: cleanedRows) { $0.terminal ?? -1 }

        return grouped
            .compactMap { terminal, items -> AirportDisplayRow? in

                guard terminal >= 0 else { return nil }

                if terminal == 0 { return nil }

                let isTBIT = terminal == 999 && selectedAirport == .lax
                let isLive = isTBIT || items.contains { $0.sourceType == .live }

                let title: String = isTBIT ? "Terminal B" : "Terminal \(terminal)"

                let subtitle: String = isTBIT
                    ? "Tom Bradley International Terminal"
                    : cleanedTerminalSubtitle(
                        title: title,
                        subtitle: items.first?.checkpointName ?? "Security"
                    )

                let observedAt = items.map(\.observedAt).max()
                let isClosed = items.allSatisfy(\.isClosed)

                let general = items.first(where: { $0.queueType == .general && !$0.isClosed })?.minutes
                let precheck = items.first(where: { $0.queueType == .precheck && !$0.isClosed })?.minutes

                let metrics: [AirportMetric]

                if isClosed {
                    metrics = [AirportMetric(label: "Closed", minutes: nil)]
                } else if isTBIT {
                    metrics = [
                        AirportMetric(label: "General", minutes: general ?? precheck),
                        AirportMetric(label: "PreCheck", minutes: precheck ?? general)
                    ]
                } else {
                    metrics = metricsForRow(
                        general: general,
                        precheck: precheck,
                        items: items,
                        isClosed: isClosed
                    )
                }

                return AirportDisplayRow(
                    id: "\(selectedAirport.rawValue)-T\(terminal)",
                    title: title,
                    subtitle: subtitle,
                    metrics: metrics,
                    observedAt: observedAt,
                    isClosed: isClosed,
                    isLive: isLive
                )
            }
            .sorted { lhs, rhs in
                if lhs.title == "Terminal B" { return true }
                if rhs.title == "Terminal B" { return false }
                return lhs.title < rhs.title
            }
    }

    private func cleanedTerminalSubtitle(title: String, subtitle: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmedSubtitle.isEmpty {
            return "Security"
        }

        if trimmedTitle == trimmedSubtitle {
            return "Security"
        }

        return subtitle
    }

    private func metricsForRow(
        general: Int?,
        precheck: Int?,
        items: [WaitTimeEstimate],
        isClosed: Bool
    ) -> [AirportMetric] {

        if isClosed {
            return [
                AirportMetric(label: "Closed", minutes: nil)
            ]
        }

        if general != nil && precheck != nil {
            return [
                AirportMetric(label: "General", minutes: general),
                AirportMetric(label: "PreCheck", minutes: precheck)
            ]
        }

        if precheck != nil {
            return [
                AirportMetric(label: "PreCheck", minutes: precheck)
            ]
        }

        if general != nil {
            return [
                AirportMetric(label: "Wait", minutes: general)
            ]
        }

        let bestMinutes = items
            .filter { !$0.isClosed }
            .map(\.minutes)
            .min()

        return [
            AirportMetric(label: "Wait", minutes: bestMinutes)
        ]
    }
}

extension Array {
    func uniqued<T: Hashable>(by key: (Element) -> T) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert(key($0)).inserted }
    }
}

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

            VStack(alignment: .leading, spacing: 10) {

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

                    if row.isLive {
                        liveStatusPill()
                    } else {
                        estimatedStatusPill()
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                }

                HStack(spacing: 10) {

                    if row.isClosed {
                        closedPill()
                    } else {
                        ForEach(row.metrics) { metric in
                            metricPill(metric, isLive: row.isLive)
                        }
                    }
                }
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

    private func liveStatusPill() -> some View {
        HStack(spacing: 6) {
            LivePulseDot()

            Text("LIVE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.10))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private func estimatedStatusPill() -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)

            Text("ESTIMATED")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.10))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private func closedPill() -> some View {

        Text("Closed")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.red)
            .frame(width: 92, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
    }

    private func metricPill(_ metric: AirportMetric, isLive: Bool = false) -> some View {

        VStack(spacing: 4) {

            if isLive {

                HStack(spacing: 6) {
                    LivePulseDot()

                    Text("\(metric.minutes ?? 0)m")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                }

                Text(metric.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))

            } else if metric.minutes == 0 {

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

            } else {

                Text("\(metric.minutes ?? 0)m")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text(metric.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .frame(width: 92, height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    isLive
                    ? Color.green.opacity(0.10)
                    : Color.black.opacity(0.22)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isLive
                            ? Color.green.opacity(0.22)
                            : Color.white.opacity(0.10),
                            lineWidth: 1
                        )
                )
        )
    }
}
