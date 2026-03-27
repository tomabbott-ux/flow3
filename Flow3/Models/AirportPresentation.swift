import Foundation

extension FlowAirport {

    var prefersCheckpointPresentation: Bool {
        switch self {

        // Checkpoint-style presentation
        case .atl, .ist, .slc, .iah, .ham, .dus, .edi, .str, .bru,
             .arn, .got, .osl, .doh, .zrh, .hel,
             .yvr, .yyc, .den, .dfw, .hou, .mco, .pit, .phx,
             .phl, .san, .las, .bos, .sea, .sfo,
             .bna, .tpa, .dtw, .clt, .ewr, .bwi, .dca, .cle, .pdx,
             .icn, .mad, .ber, .bcn, .pmi, .agp, .alc,
             .svq, .bio, .ibz, .vlc, .tfs, .lpa, .del:
            return true

        // Terminal-style presentation
        case .jfk, .lhr, .lga, .cph, .yyz,
             .ams, .cdg, .dxb, .sin, .fra,
             .lax, .ord, .fco, .hnd, .syd, .msp,
             .mia, .dub:
            return false
        }
    }
}
