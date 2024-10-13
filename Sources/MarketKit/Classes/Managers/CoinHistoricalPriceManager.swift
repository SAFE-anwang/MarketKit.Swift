import Foundation

class CoinHistoricalPriceManager {
    private let storage: CoinHistoricalPriceStorage
    private let hsProvider: HsProvider

    init(storage: CoinHistoricalPriceStorage, hsProvider: HsProvider) {
        self.storage = storage
        self.hsProvider = hsProvider
    }
}

extension CoinHistoricalPriceManager {
    func cachedCoinHistoricalPriceValue(coinUid: String, currencyCode: String, timestamp: TimeInterval) -> Decimal? {
        try? storage.coinHistoricalPrice(coinUid: coinUid, currencyCode: currencyCode, timestamp: timestamp)?.value
    }

    func coinHistoricalPriceValue(coinUid: String, currencyCode: String, timestamp: TimeInterval) async throws -> Decimal {
        
        if coinUid.isSafeCoin {
            return try await safeCoinHistoricalPriceValue(coinUid: coinUid, currencyCode: currencyCode, timestamp: timestamp)
            
        }else {
            
            let response = try await hsProvider.historicalCoinPrice(coinUid: coinUid, currencyCode: currencyCode, timestamp: timestamp)

            guard abs(Int(timestamp) - response.timestamp) < 24 * 60 * 60 else { // 1 day
                throw ResponseError.returnedTimestampIsTooInaccurate
            }

            try? storage.save(coinHistoricalPrice: CoinHistoricalPrice(coinUid: coinUid, currencyCode: currencyCode, value: response.price, timestamp: timestamp))

            return response.price
        }
    }
}

extension CoinHistoricalPriceManager {

    func safeCoinHistoricalPriceValue(coinUid: String, currencyCode: String, timestamp: TimeInterval) async throws -> Decimal {
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let oneYearAgoTimestamp = oneYearAgo.timeIntervalSince1970
        guard timestamp > oneYearAgoTimestamp else {throw ResponseError.historicalPriceTimestampIsTimeLimitExceeded }
        let response = try await hsProvider.safeHistoricalCoinPrice(coinUid: "safe-anwang", currencyCode: currencyCode, timestamp: timestamp)

        try? storage.save(coinHistoricalPrice: CoinHistoricalPrice(coinUid: coinUid, currencyCode: currencyCode, value: response.price, timestamp: timestamp))

        return response.price
    }
}

extension CoinHistoricalPriceManager {
    enum ResponseError: Error {
        case returnedTimestampIsTooInaccurate
        case historicalPriceTimestampIsTimeLimitExceeded
    }
}
