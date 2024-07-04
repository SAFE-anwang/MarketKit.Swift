import Foundation

extension Decimal {
    init?(convertibleValue: Any?) {
        guard let convertibleValue = convertibleValue as? CustomStringConvertible,
              let value = Decimal(string: convertibleValue.description)
        else {
            return nil
        }

        self = value
    }
}

public extension TimeInterval {
    static func minutes(_ count: Self) -> Self {
        count * 60
    }

    static func hours(_ count: Self) -> Self {
        count * minutes(60)
    }

    static func days(_ count: Self) -> Self {
        count * hours(24)
    }
}


public let safeCoinUid = "safe-anwang"
public let safe4CoinUid = "safe4-anwang"
public let isSafe4TestNet = true

public extension String {
    var isSafeCoin: Bool {
        let safeUids = [safeCoinUid, safe4CoinUid]
        return safeUids.contains(self)
    }
    
    var isSafe4Test: Bool {
        self == safe4CoinUid && isSafe4TestNet
    }
}

public extension Coin {
    var isSafeCoin: Bool {
        uid.isSafeCoin
    }
}

