import Foundation
import StoreKit
import Combine

@MainActor
final class TipStore: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case ready(Product)
        case purchasing
        case purchased
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var priceText: String = ""

    private let productID: String

    init(productID: String) {
        self.productID = productID
    }

    func load() async {
        // Avoid reloading if we already loaded
        if case .ready = state { return }
        if case .purchasing = state { return }

        state = .loading
        do {
            let products = try await Product.products(for: [productID])
            guard let product = products.first else {
                state = .failed("Product not found.")
                return
            }
            priceText = product.displayPrice
            state = .ready(product)

            // Listen for any transaction updates in the background
            Task.detached { [weak self] in
                await self?.listenForTransactions()
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func purchase() async {
        guard case let .ready(product) = state else { return }
        state = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                state = .purchased
            case .userCancelled:
                state = .ready(product)
            case .pending:
                state = .ready(product)
            @unknown default:
                state = .failed("Unknown purchase result.")
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error ?? NSError(domain: "TipStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unverified transaction"])
        case .verified(let safe):
            return safe
        }
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            do {
                let transaction = try checkVerified(update)
                await transaction.finish()
                await MainActor.run {
                    // Reflect success if we weren’t already
                    if case .purchased = self.state {
                        // no-op
                    } else {
                        self.state = .purchased
                    }
                }
            } catch {
                await MainActor.run {
                    if case .failed = self.state {
                        // keep the error
                    } else {
                        self.state = .failed("Transaction update error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
