import Foundation

extension FlowAirport {

    var prefersCheckpointPresentation: Bool {
        switch self {

        case .atl, .ist, .slc, .iah, .ham, .dus, .edi, .str, .bru,
             .arn, .got, .osl, .doh, .zrh, .hel,
             .yvr, .yyc, .den, .dfw, .hou, .mco, .phx,
             .phl, .san, .las, .bos, .sea, .mia, .sfo,
             .bna, .tpa, .dtw, .clt, .ewr, .bwi, .dca, .icn, .pdx:
            return true

        case .jfk, .lhr, .lga, .cph, .yyz,
             .ams, .cdg, .dxb, .sin, .fra, .mad,
             .lax, .ord, .fco, .bcn, .hnd, .syd,
             .msp:
            return false
        }
    }
}
