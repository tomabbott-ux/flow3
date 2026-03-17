import Foundation

extension FlowAirport {

    var prefersCheckpointPresentation: Bool {
        switch self {

        case .atl, .ist, .slc, .iah, .ham, .dus, .edi, .str, .bru,
             .arn, .got, .osl, .doh, .zrh, .hel,
             .yvr, .yyc, .den, .dfw, .hou, .mco, .pit, .phx,
             .phl, .san, .las, .bos, .sea, .mia, .cle, .sfo,
             .bna, .tpa, .dtw, .clt, .ewr, .bwi, .dca, .icn, .pdx,
             .mad,.pmi, .agp, .alc, .ber, .svq, .bio, .ibz, .vlc, .tfs, .lpa, .bcn:
            return true

        case .jfk, .lhr, .lga, .cph, .yyz,
             .ams, .cdg, .dxb, .sin, .fra,
             .lax, .ord, .fco, .hnd, .syd,
             .msp:
            return false
        }
    }
}
