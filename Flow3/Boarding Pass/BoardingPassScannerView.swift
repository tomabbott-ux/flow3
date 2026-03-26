import SwiftUI
import VisionKit

struct BoardingPassScanResult {
    let rawText: String
    let flightNumber: String
    let flightDate: Date?
}

struct BoardingPassScannerView: UIViewControllerRepresentable {

    var onResult: (BoardingPassScanResult) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {

        let controller = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .fast,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )

        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {

        let parent: BoardingPassScannerView

        init(_ parent: BoardingPassScannerView) {
            self.parent = parent
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            guard case .text(let textItem) = item else { return }

            let raw = textItem.transcript.uppercased()

            let flightNumber = extractFlightNumber(from: raw)

            let result = BoardingPassScanResult(
                rawText: raw,
                flightNumber: flightNumber ?? "",
                flightDate: nil
            )

            parent.onResult(result)
        }

        private func extractFlightNumber(from text: String) -> String? {
            let pattern = #"[A-Z0-9]{2,3}\d{1,4}"#
            if let range = text.range(of: pattern, options: .regularExpression) {
                return String(text[range])
            }
            return nil
        }
    }
}
