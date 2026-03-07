import Foundation

extension FlowAirport {

    var prefersCheckpointPresentation: Bool {
        switch self {
        case .atl, .yvr, .yyc, .den, .dfw, .hou, .mco, .phx, .phl:
            return true

        case .jfk, .lhr, .yyz, .ams, .cdg, .dxb, .sin, .fra, .mad,
             .sfo, .lax, .ord, .las, .bos, .sea, .san, .mia,
             .bcn, .fco, .hnd, .icn, .syd:
            return false
        }
    }
}
