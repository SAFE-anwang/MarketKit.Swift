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

    static func midnightUTC() -> Self {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)

        var components = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: now)

        components.hour = 0
        components.minute = 0
        components.second = 0

        guard let todayMidnightUTC = calendar.date(from: components) else {
            return 0
        }

        return todayMidnightUTC.timeIntervalSince1970
    }
}

public let isSafe4TestNet = false
public let safeCoinUid = "safe-anwang"
public let safe4CoinUid = "safe4-anwang"
public let safe4CoinUid_src = "\(SAFE4_Custom_CoinUid)|eip20:\(safe4SrcContract)"
public let safe4CoinUid_eth = "\(SAFE4_Custom_CoinUid)|eip20:\(safe4EthContract)"
public let safe4CoinUid_bsc = "\(SAFE4_Custom_CoinUid)|eip20:\(safe4BscContract)"
public let safe4CoinUid_pol = "\(SAFE4_Custom_CoinUid)|eip20:\(safe4PolContract)"

public let safe4BlockchainUid = "safe4-anwang"
public let SAFE4_Custom_CoinUid = "custom-safe4-anwang"
public let safe4UsdtCoinUid = "Safe4USDT"
public let safe4UsdtContract = "0x9c1246a4bb3c57303587e594a82632c3171662c9"
public let safe4EthContract = "0xee9c1ea4dcf0aaf4ff2d78b6ff83aa69797b65eb"
public let safe4BscContract = "0x4d7fa587ec8e50bd0e9cd837cb4da796f47218a1"
public let safe4PolContract = "0xb7Dd19490951339fE65E341Df6eC5f7f93FF2779"
public let safe4SrcContract = "0x0000000000000000000000000000000000001101"

public extension String {

    var isSafeCoin: Bool {
        let safeUids = [safeCoinUid, safe4CoinUid, safe4UsdtCoinUid, safe4CoinUid_src, safe4CoinUid_eth, safe4CoinUid_bsc, safe4CoinUid_pol]
        return safeUids.contains(self)// || isSafeFourCustomCoin
    }
    
    var isSafe3Coin: Bool {
        let safeUids = [safeCoinUid]
        return safeUids.contains(self)
    }
    
    var isSafe4Coin: Bool {
        let safeUids = [safe4CoinUid, safe4UsdtCoinUid, safe4UsdtCoinUid, safe4CoinUid_src, safe4CoinUid_eth, safe4CoinUid_bsc, safe4CoinUid_pol]
        return safeUids.contains(self)
    }
    
    var isSafe4Test: Bool {
        isSafe4Coin && isSafe4TestNet
    }
    
    var isSafeFourCustomCoin: Bool {
        self.contains("custom-safe4-anwang") || self.contains("custom-safe4-anwang|eip20")
    }
    
    var isSafeUsdtContract: Bool {
        self.lowercased() == safe4UsdtContract.lowercased()
    }

    func coinCode(code: String, contract: String? = nil) -> String {
        safe4UsdtContract.lowercased() == contract?.lowercased() ? "USDT": code
    }

    func coinName(code: String, contract: String? = nil) -> String {
        safe4UsdtContract.lowercased() == contract?.lowercased() ? "Safe4USDT": code
    }
    
    static func isSafeUsdtCoin(contract: String) -> Bool {
        contract.lowercased() == safe4UsdtContract.lowercased()
    }
}

public extension Coin {
    var isSafeCoin: Bool {
        uid.isSafeCoin
    }
    
    var isSafeUsdtCoin: Bool {
        uid == safe4UsdtCoinUid
    }
}

