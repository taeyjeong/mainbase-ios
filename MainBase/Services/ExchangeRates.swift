import Combine
import Foundation

/// Today's US dollar rates for every PayCurrency, so admin screens can show a dollar figure
/// next to wages and payouts in other currencies. Rates are the European Central Bank's daily
/// reference rates via Frankfurter (no API key), fetched once per launch. A paid month keeps
/// the rate from when it was marked paid (PayoutRecord.usdRate) instead of today's.
@MainActor
final class ExchangeRates: ObservableObject {
    static let shared = ExchangeRates()

    /// Units of each currency per 1 USD, e.g. [.jpy: 158.09].
    @Published private(set) var perDollar: [PayCurrency: Double] = [.usd: 1]

    private var isLoaded = false
    private var isLoading = false

    private init() {}

    /// Fetches the rates unless they're already loaded. On failure dollar figures just stay
    /// hidden, and the next call retries.
    func load() async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let symbols = PayCurrency.allCases.filter { $0 != .usd }.map(\.rawValue).joined(separator: ",")
        guard let url = URL(string: "https://api.frankfurter.dev/v1/latest?base=USD&symbols=\(symbols)"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(Response.self, from: data)
        else { return }
        var rates: [PayCurrency: Double] = [.usd: 1]
        for (code, rate) in response.rates {
            if let currency = PayCurrency(rawValue: code), rate > 0 { rates[currency] = rate }
        }
        perDollar = rates
        isLoaded = true
    }

    /// "≈ $20.15" for an amount in another currency, using `rate` (units per USD) if given and
    /// today's rate otherwise. nil for USD amounts and while the rate is unknown.
    func dollarsText(_ amount: Double?, in currency: PayCurrency, rate: Double? = nil) -> String? {
        guard currency != .usd, let amount, let rate = rate ?? perDollar[currency], rate > 0 else { return nil }
        return "≈ " + (amount / rate).formatted(PayCurrency.usd.format)
    }

    private struct Response: Decodable {
        let rates: [String: Double]
    }
}
