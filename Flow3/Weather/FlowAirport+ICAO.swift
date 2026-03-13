import Foundation

extension FlowAirport {

    var icaoCode: String {
        switch self {

        case .atl: return "KATL"
        case .jfk: return "KJFK"
        case .lhr: return "EGLL"
        case .ist: return "LTFM"
        case .lga: return "KLGA"

        case .ham: return "EDDH"
        case .cph: return "EKCH"
        case .dus: return "EDDL"
        case .edi: return "EGPH"
        case .str: return "EDDS"
        case .bru: return "EBBR"

        case .phl: return "KPHL"
        case .mco: return "KMCO"
        case .slc: return "KSLC"
        case .iah: return "KIAH"
        case .bna: return "KBNA"
        case .tpa: return "KTPA"
        case .dtw: return "KDTW"
        case .clt: return "KCLT"
        case .ewr: return "KEWR"
        case .msp: return "KMSP"
        case .bwi: return "KBWI"
        case .dca: return "KDCA"
        case .pdx: return "KPDX"

        case .yyz: return "CYYZ"
        case .yvr: return "CYVR"
        case .yyc: return "CYYC"

        case .den: return "KDEN"
        case .dfw: return "KDFW"
        case .hou: return "KHOU"
        case .phx: return "KPHX"

        case .ams: return "EHAM"
        case .cdg: return "LFPG"
        case .dxb: return "OMDB"
        case .sin: return "WSSS"
        case .fra: return "EDDF"
        case .mad: return "LEMD"
        case .bcn: return "LEBL"
        case .pmi: return "LEPA"
        case .agp: return "LEMG"
        case .alc: return "LEAL"
        case .svq: return "LEZL"
        case .bio: return "LEBB"
        case .ibz: return "LEIB"
        case .vlc: return "LEVC"
        case .tfs: return "GCTS"
        case .lpa: return "GCLP"
        case .sfo: return "KSFO"
        case .lax: return "KLAX"
        case .ord: return "KORD"
        case .las: return "KLAS"
        case .bos: return "KBOS"
        case .sea: return "KSEA"
        case .san: return "KSAN"
        case .mia: return "KMIA"

        case .fco: return "LIRF"
        case .hnd: return "RJTT"
        case .icn: return "RKSI"
        case .syd: return "YSSY"

        case .doh: return "OTHH"
        case .arn: return "ESSA"
        case .got: return "ESGG"
        case .osl: return "ENGM"
        case .zrh: return "LSZH"
        case .hel: return "EFHK"
        }
    }
}
