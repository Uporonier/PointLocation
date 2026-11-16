import Combine
import MapKit

struct PlaceSuggestion: Identifiable {
    let id = UUID()
    let completion: MKLocalSearchCompletion

    var title: String { completion.title }
    var subtitle: String { completion.subtitle }
}

@MainActor
final class PlaceSearchController: NSObject, ObservableObject {
    @Published private(set) var suggestions: [PlaceSuggestion] = []
    @Published private(set) var isCompleting = false
    @Published private(set) var completionFailed = false

    private let completer = MKLocalSearchCompleter()
    private var currentSearch: MKLocalSearch?
    private var currentQuery = ""

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String, region: MKCoordinateRegion) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        completer.region = region

        guard !query.isEmpty else {
            clearSuggestions()
            return
        }

        currentQuery = query
        completionFailed = false
        isCompleting = true
        completer.queryFragment = query
    }

    func update(region: MKCoordinateRegion) {
        completer.region = region
    }

    func clearSuggestions() {
        currentQuery = ""
        completer.cancel()
        completer.queryFragment = ""
        suggestions = []
        isCompleting = false
        completionFailed = false
    }

    func cancelAll() {
        clearSuggestions()
        currentSearch?.cancel()
        currentSearch = nil
    }

    func resolve(_ suggestion: PlaceSuggestion, region: MKCoordinateRegion) async throws -> MKMapItem {
        // A completion identifies a place already. Do not bias it toward the
        // old simulated location (which may be on a different continent).
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        do {
            return try await firstMapItem(for: request)
        } catch {
            try Task.checkCancellation()
            guard isNoResults(error) else { throw error }
        }

        // Some providers return suggestions whose place token no longer
        // resolves. Retry their full address as text, without the old region.
        let query = [suggestion.title, suggestion.subtitle]
            .filter { !$0.isEmpty }.joined(separator: " ")
        let fallback = MKLocalSearch.Request()
        fallback.naturalLanguageQuery = query
        fallback.resultTypes = [.address, .pointOfInterest]
        return try await firstMapItem(for: fallback)
    }

    func resolve(query: String, region: MKCoordinateRegion) async throws -> MKMapItem {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = [.address, .pointOfInterest]
        do {
            return try await firstMapItem(for: request)
        } catch {
            try Task.checkCancellation()
            guard isNoResults(error) else { throw error }
        }
        let fallback = MKLocalSearch.Request()
        fallback.naturalLanguageQuery = query
        fallback.resultTypes = [.address, .pointOfInterest]
        return try await firstMapItem(for: fallback)
    }

    private func isNoResults(_ error: Error) -> Bool {
        if case PlaceSearchError.noResults = error { return true }
        let nsError = error as NSError
        return nsError.domain == MKErrorDomain &&
            nsError.code == Int(MKError.Code.placemarkNotFound.rawValue)
    }

    private func firstMapItem(for request: MKLocalSearch.Request) async throws -> MKMapItem {
        try Task.checkCancellation()
        currentSearch?.cancel()

        let search = MKLocalSearch(request: request)
        currentSearch = search
        defer {
            if currentSearch === search {
                currentSearch = nil
            }
        }

        let response: MKLocalSearch.Response
        do {
            response = try await search.start()
        } catch {
            try Task.checkCancellation()
            if isNoResults(error) { throw PlaceSearchError.noResults }
            throw error
        }
        try Task.checkCancellation()

        guard let item = response.mapItems.first else {
            throw PlaceSearchError.noResults
        }
        return item
    }
}

extension PlaceSearchController: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let query = completer.queryFragment
        let results = completer.results
        Task { @MainActor [weak self] in
            guard let self, currentQuery == query else { return }
            suggestions = results.prefix(8).map(PlaceSuggestion.init)
            isCompleting = false
            completionFailed = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        let query = completer.queryFragment
        Task { @MainActor [weak self] in
            guard let self, currentQuery == query else { return }
            suggestions = []
            isCompleting = false
            completionFailed = true
        }
    }
}

enum PlaceSearchError: LocalizedError {
    case noResults

    var errorDescription: String? {
        "地图服务未返回这个地点。请加上城市或校区名称后重试，例如“济南 山东大学 中心校区”；也可以退出搜索，在地图上放大并点选。原来的选点没有改变。"
    }
}
