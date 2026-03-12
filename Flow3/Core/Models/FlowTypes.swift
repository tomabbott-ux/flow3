import Foundation

enum FlowAirport: String, CaseIterable, Identifiable, Codable, Hashable {

    case atl = "ATL"
    case jfk = "JFK"
    case lhr = "LHR"
    case ist = "IST"
    case lga = "LGA"
    case ham = "HAM"
    case cph = "CPH"
    case dus = "DUS"
    case edi = "EDI"
    case str = "STR"
    case bru = "BRU"
    case arn = "ARN"
    case got = "GOT"
    case osl = "OSL"
    case doh = "DOH"
    case zrh = "ZRH"
    case hel = "HEL"

    case phl = "PHL"
    case mco = "MCO"
    case slc = "SLC"
    case iah = "IAH"
    case bna = "BNA"
    case tpa = "TPA"
    case dtw = "DTW"
    case clt = "CLT"
    case ewr = "EWR"
    case msp = "MSP"
    case bwi = "BWI"
    case dca = "DCA"
    case pdx = "PDX"

    case yyz = "YYZ"
    case yvr = "YVR"
    case yyc = "YYC"

    case den = "DEN"
    case dfw = "DFW"
    case hou = "HOU"
    case phx = "PHX"

    case ams = "AMS"
    case cdg = "CDG"
    case dxb = "DXB"
    case sin = "SIN"
    case fra = "FRA"
    case mad = "MAD"
    case pmi = "PMI"
    case agp = "AGP"
    case alc = "ALC"
    case svq = "SVQ"
    case bio = "BIO"
    case ibz = "IBZ"
    case vlc = "VLC"
    case tfs = "TFS"
    case lpa = "LPA"
    
    case sfo = "SFO"
    case lax = "LAX"
    case ord = "ORD"
    case las = "LAS"
    case bos = "BOS"
    case sea = "SEA"
    case san = "SAN"
    case mia = "MIA"

    case bcn = "BCN"
    case fco = "FCO"
    case hnd = "HND"
    case icn = "ICN"
    case syd = "SYD"

    var id: String { rawValue }

    var displayName: String {
        switch self {

        case .atl: return "Atlanta"
        case .jfk: return "New York JFK"
        case .lhr: return "London Heathrow"
        case .ist: return "Istanbul Airport"
        case .lga: return "New York LaGuardia"
        case .ham: return "Hamburg"
        case .cph: return "Copenhagen"
        case .dus: return "Düsseldorf"
        case .edi: return "Edinburgh"
        case .str: return "Stuttgart"
        case .bru: return "Brussels"
        case .arn: return "Stockholm Arlanda"
        case .got: return "Gothenburg Landvetter"
        case .osl: return "Oslo"
        case .doh: return "Doha Hamad"
        case .zrh: return "Zurich"
        case .hel: return "Helsinki"

        case .phl: return "Philadelphia"
        case .mco: return "Orlando"
        case .slc: return "Salt Lake City"
        case .iah: return "Houston Intercontinental"
        case .bna: return "Nashville"
        case .tpa: return "Tampa"
        case .dtw: return "Detroit"
        case .clt: return "Charlotte"
        case .ewr: return "Newark"
        case .msp: return "Minneapolis St Paul"
        case .bwi: return "Baltimore Washington"
        case .dca: return "Washington Reagan"
        case .pdx: return "Portland"

        case .yyz: return "Toronto Pearson"
        case .yvr: return "Vancouver"
        case .yyc: return "Calgary"

        case .den: return "Denver"
        case .dfw: return "Dallas Fort Worth"
        case .hou: return "Houston Hobby"
        case .phx: return "Phoenix Sky Harbor"

        case .ams: return "Amsterdam Schiphol"
        case .cdg: return "Paris Charles de Gaulle"
        case .dxb: return "Dubai"
        case .sin: return "Singapore"
        case .fra: return "Frankfurt"
        case .mad: return "Madrid"
        case .pmi: return "Palma"
        case .agp: return "Malaga"
        case .alc: return "Alicante"
        case .svq: return "Seville"
        case .bio: return "Bilbao"
        case .ibz: return "Ibiza"
        case .vlc: return "Valencia"
        case .tfs: return "Tenerife South"
        case .lpa: return "Gran Canaria"

        case .sfo: return "San Francisco"
        case .lax: return "Los Angeles"
        case .ord: return "Chicago O'Hare"
        case .las: return "Las Vegas"
        case .bos: return "Boston Logan"
        case .sea: return "Seattle Tacoma"
        case .san: return "San Diego"
        case .mia: return "Miami"

        case .bcn: return "Barcelona"
        case .fco: return "Rome Fiumicino"
        case .hnd: return "Tokyo Haneda"
        case .icn: return "Seoul Incheon"
        case .syd: return "Sydney"
        }
    }

    var shortName: String {
        switch self {

        case .atl: return "Atlanta (ATL)"
        case .jfk: return "New York (JFK)"
        case .lhr: return "London Heathrow (LHR)"
        case .ist: return "Istanbul (IST)"
        case .lga: return "New York LaGuardia (LGA)"
        case .ham: return "Hamburg (HAM)"
        case .cph: return "Copenhagen (CPH)"
        case .dus: return "Düsseldorf (DUS)"
        case .edi: return "Edinburgh (EDI)"
        case .str: return "Stuttgart (STR)"
        case .bru: return "Brussels (BRU)"
        case .arn: return "Stockholm Arlanda (ARN)"
        case .got: return "Gothenburg Landvetter (GOT)"
        case .osl: return "Oslo (OSL)"
        case .doh: return "Doha Hamad (DOH)"
        case .zrh: return "Zurich (ZRH)"
        case .hel: return "Helsinki (HEL)"

        case .phl: return "Philadelphia (PHL)"
        case .mco: return "Orlando (MCO)"
        case .slc: return "Salt Lake City (SLC)"
        case .iah: return "Houston IAH (IAH)"
        case .bna: return "Nashville (BNA)"
        case .tpa: return "Tampa (TPA)"
        case .dtw: return "Detroit (DTW)"
        case .clt: return "Charlotte (CLT)"
        case .ewr: return "Newark (EWR)"
        case .msp: return "Minneapolis St Paul (MSP)"
        case .bwi: return "Baltimore Washington (BWI)"
        case .dca: return "Washington Reagan (DCA)"
        case .pdx: return "Portland (PDX)"

        case .yyz: return "Toronto (YYZ)"
        case .yvr: return "Vancouver (YVR)"
        case .yyc: return "Calgary (YYC)"

        case .den: return "Denver (DEN)"
        case .dfw: return "Dallas (DFW)"
        case .hou: return "Houston (HOU)"
        case .phx: return "Phoenix (PHX)"

        case .ams: return "Amsterdam (AMS)"
        case .cdg: return "Paris (CDG)"
        case .dxb: return "Dubai (DXB)"
        case .sin: return "Singapore (SIN)"
        case .fra: return "Frankfurt (FRA)"
        case .mad: return "Madrid (MAD)"
        case .pmi: return "Palma (PMI)"
        case .agp: return "Malaga (AGP)"
        case .alc: return "Alicante (ALC)"
        case .svq: return "Seville (SVQ)"
        case .bio: return "Bilbao (BIO)"
        case .ibz: return "Ibiza (IBZ)"
        case .vlc: return "Valencia (VLC)"
        case .tfs: return "Tenerife South (TFS)"
        case .lpa: return "Gran Canaria (LPA)"
            
        case .sfo: return "San Francisco (SFO)"
        case .lax: return "Los Angeles (LAX)"
        case .ord: return "Chicago (ORD)"
        case .las: return "Las Vegas (LAS)"
        case .bos: return "Boston (BOS)"
        case .sea: return "Seattle (SEA)"
        case .san: return "San Diego (SAN)"
        case .mia: return "Miami (MIA)"

        case .bcn: return "Barcelona (BCN)"
        case .fco: return "Rome (FCO)"
        case .hnd: return "Tokyo (HND)"
        case .icn: return "Seoul (ICN)"
        case .syd: return "Sydney (SYD)"
        }
    }

    var timeZone: TimeZone {
        switch self {

        case .atl, .jfk, .lga, .phl, .mco, .bos, .mia, .yyz, .tpa, .dtw, .clt, .ewr, .bwi, .dca:
            return TimeZone(identifier: "America/New_York")!

        case .bna, .dfw, .hou, .ord, .iah, .msp:
            return TimeZone(identifier: "America/Chicago")!

        case .edi, .lhr:
            return TimeZone(identifier: "Europe/London")!

        case .den, .yyc, .slc:
            return TimeZone(identifier: "America/Denver")!

        case .phx:
            return TimeZone(identifier: "America/Phoenix")!

        case .lax, .sfo, .las, .sea, .san, .yvr, .pdx:
            return TimeZone(identifier: "America/Los_Angeles")!

        case .ist:
            return TimeZone(identifier: "Europe/Istanbul")!

        case .ham, .dus, .fra, .str:
            return TimeZone(identifier: "Europe/Berlin")!

        case .bru:
            return TimeZone(identifier: "Europe/Brussels")!

        case .ams:
            return TimeZone(identifier: "Europe/Amsterdam")!

        case .cdg:
            return TimeZone(identifier: "Europe/Paris")!

        case .mad, .bcn, .pmi, .agp, .alc, .svq, .bio, .ibz, .vlc:
            return TimeZone(identifier: "Europe/Madrid")!
            
        case .tfs, .lpa:
            return TimeZone(identifier: "Atlantic/Canary")!
            
        case .fco:
            return TimeZone(identifier: "Europe/Rome")!

        case .cph:
            return TimeZone(identifier: "Europe/Copenhagen")!

        case .arn, .got:
            return TimeZone(identifier: "Europe/Stockholm")!

        case .osl:
            return TimeZone(identifier: "Europe/Oslo")!

        case .doh:
            return TimeZone(identifier: "Asia/Qatar")!

        case .zrh:
            return TimeZone(identifier: "Europe/Zurich")!

        case .hel:
            return TimeZone(identifier: "Europe/Helsinki")!

        case .dxb:
            return TimeZone(identifier: "Asia/Dubai")!

        case .sin:
            return TimeZone(identifier: "Asia/Singapore")!

        case .hnd:
            return TimeZone(identifier: "Asia/Tokyo")!

        case .icn:
            return TimeZone(identifier: "Asia/Seoul")!

        case .syd:
            return TimeZone(identifier: "Australia/Sydney")!
        }
    }
}
