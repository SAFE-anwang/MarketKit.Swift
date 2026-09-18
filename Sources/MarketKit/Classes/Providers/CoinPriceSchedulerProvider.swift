import Foundation

private enum CoinPriceSyncError: Error {
    case incomplete
}

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

        var syncFailed = false

        let regularCoinUids = coinUids.filter {
            !$0.isSafeCoin && !$0.isSafe4Src20Token
        }
        if !regularCoinUids.isEmpty {
            do {
                let prices = try await provider.regularCoinPrices(
                    coinUids: regularCoinUids,
                    walletCoinUids: walletCoinUids,
                    currencyCode: currencyCode
                )
                let returnedUids = Set(prices.map { $0.coinUid.lowercased() })
                handle(updatedCoinPrices: prices)
                guard Set(regularCoinUids.map { $0.lowercased() }).isSubset(of: returnedUids) else {
                    throw CoinPriceSyncError.incomplete
                }
            } catch {
                syncFailed = true
            }
        }

        let safeNativeRequested = coinUids.contains {
            $0.isSafeCoin && $0.caseInsensitiveCompare(safe4UsdtCoinUid) != .orderedSame
        }
        if safeNativeRequested {
            do {
                let safePrices = try await provider.safeCoinPrices(currencyCode: currencyCode)
                guard let safePrice = safePrices.first else {
                    throw CoinPriceSyncError.incomplete
                }

                let mappedSafePrices = coinUids
                    .filter { $0.isSafeCoin && $0.caseInsensitiveCompare(safe4UsdtCoinUid) != .orderedSame }
                    .map { uid in
                        CoinPrice(
                            coinUid: uid,
                            currencyCode: safePrice.currencyCode,
                            value: safePrice.value,
                            diff24h: safePrice.diff24h,
                            diff1d: safePrice.diff1d,
                            timestamp: safePrice.timestamp
                        )
                    }
                handle(updatedCoinPrices: mappedSafePrices)
            } catch {
                syncFailed = true
            }
        }

        // SRC20 pricing is independent of the regular and SAFE price endpoints.
        // A malformed SRC20 payload must not prevent either source from updating.
        let requestedSrc20Uids = Set(coinUids.filter(\.isSafe4Src20Token).map { $0.lowercased() })
        if !requestedSrc20Uids.isEmpty {
            do {
                let src20Prices = try await provider.safeAllSrc20CoinPrice()
                let src20CoinPrices = src20Prices.map {
                    CoinPrice(
                        coinUid: TokenQuery(blockchainType: .safe4, tokenType: .eip20(address: $0.address)).customCoinUid.lowercased(),
                        currencyCode: "USD",
                        value: Decimal(string: $0.price) ?? 0,
                        diff24h: Decimal(string: $0.change),
                        diff1d: Decimal(string: $0.change),
                        timestamp: Date().timeIntervalSince1970
                    )
                }
                let returnedSrc20Uids = Set(src20CoinPrices.map { $0.coinUid.lowercased() })
                handle(updatedCoinPrices: src20CoinPrices)
                guard requestedSrc20Uids.isSubset(of: returnedSrc20Uids) else {
                    throw CoinPriceSyncError.incomplete
                }
            } catch {
                syncFailed = true
            }
        }

        // Safe4 USDT intentionally uses the ordinary tether price, never SAFE's price.
        if coinUids.contains(where: { $0.caseInsensitiveCompare(safe4UsdtCoinUid) == .orderedSame }) {
            do {
                let tetherPrices = try await provider.regularCoinPrices(
                    coinUids: ["tether"],
                    walletCoinUids: ["tether"],
                    currencyCode: currencyCode
                )
                guard let tetherPrice = tetherPrices.first else {
                    throw CoinPriceSyncError.incomplete
                }
                handle(updatedCoinPrices: [CoinPrice(
                    coinUid: safe4UsdtCoinUid,
                    currencyCode: tetherPrice.currencyCode,
                    value: tetherPrice.value,
                    diff24h: tetherPrice.diff24h,
                    diff1d: tetherPrice.diff1d,
                    timestamp: tetherPrice.timestamp
                )])
            } catch {
                syncFailed = true
            }
        }

        guard !syncFailed else {
            throw CoinPriceSyncError.incomplete
        }
    }

    func notifyExpired() {
        manager.notifyExpired(coinUids: allCoinUids, currencyCode: currencyCode)
    }
}
