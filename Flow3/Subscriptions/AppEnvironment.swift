import Foundation

struct AppEnvironment {
    
    static var isTestFlight: Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        return receiptURL.lastPathComponent == "sandboxReceipt"
    }
    
}
