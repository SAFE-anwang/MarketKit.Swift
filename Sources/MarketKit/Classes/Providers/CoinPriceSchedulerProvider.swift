import Foundation

protocol ICoinPriceCoinUidDataSource: AnyObject {
    func allCoinUids(currencyCode: String) -> [String]
    func combinedCoinUids(currencyCode: String) -> ([String], [String])
}

class CoinPriceSchedulerProvider {
    private let currencyCode: String
    private let manager: CoinPriceManager
    private let provider: HsProvider

    weak var dataSource: ICoinPriceCoinUidDataSource?

    init(manager: CoinPriceManager, provider: HsProvider, currencyCode: String) {
        self.manager = manager
        self.provider = provider
        self.currencyCode = currencyCode
    }

    private var allCoinUids: [String] {
        dataSource?.allCoinUids(currencyCode: currencyCode) ?? []
    }

    private func handle(updatedCoinPrices: [CoinPrice]) {
        manager.handleUpdated(coinPrices: updatedCoinPrices, currencyCode: currencyCode)
    }
}

extension CoinPriceSchedulerProvider: ISchedulerProvider {
    var id: String {
        "CoinPriceProvider"
    }

    var lastSyncTimestamp: TimeInterval? {
        manager.lastSyncTimestamp(coinUids: allCoinUids, currencyCode: currencyCode)
    }

    var expirationInterval: TimeInterval {
        CoinPrice.expirationInterval
    }

    func sync() async throws {
        guard let (coinUids, walletCoinUids) = dataSource?.combinedCoinUids(currencyCode: currencyCode), !coinUids.isEmpty else {
            return
        }

        var coinPrices = try await provider.coinPrices(coinUids: coinUids, walletCoinUids: walletCoinUids, currencyCode: currencyCode)
        // add src20CoinPrices
        let src20Prices = try await provider.safeAllSrc20CoinPrice()
        let src20CoinPrices = src20Prices.map { CoinPrice(coinUid: TokenQuery(blockchainType: .safe4, tokenType: .eip20(address: $0.address)).customCoinUid.lowercased(), currencyCode: "USD", value: Decimal(string: $0.price) ?? 0 , diff24h: nil, diff1d: nil, timestamp: Date().timeIntervalSince1970) }
        coinPrices.append(contentsOf: src20CoinPrices)
        // add safe4 CoinPrice
        if let price = coinPrices.filter({ $0.coinUid.isSafeCoin }).first {
            coinUids
                .filter{ $0.isSafeCoin }
                .forEach{ uid in
                    let safe4CoinPrice = CoinPrice(coinUid: uid, currencyCode: price.currencyCode, value: price.value, diff24h: price.diff24h, diff1d: price.diff1d, timestamp: price.timestamp)
                    coinPrices.append(safe4CoinPrice)
            }
        }

        handle(updatedCoinPrices: coinPrices)
    }

    func notifyExpired() {
        manager.notifyExpired(coinUids: allCoinUids, currencyCode: currencyCode)
    }
}
