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
        
        if let price = coinPrices.filter({ $0.coinUid.isSafeCoin }).first {
            let value = isSafe4TestNet ? 0 : price.value
            // insert safe4 CoinPrice
            let safe4CoinPrice = CoinPrice(coinUid: safe4CoinUid, currencyCode: price.currencyCode, value: value, diff: price.diff, timestamp: price.timestamp)
            coinPrices.append(safe4CoinPrice)
        }
        
        handle(updatedCoinPrices: coinPrices)
    }

    func notifyExpired() {
        manager.notifyExpired(coinUids: allCoinUids, currencyCode: currencyCode)
    }
}
