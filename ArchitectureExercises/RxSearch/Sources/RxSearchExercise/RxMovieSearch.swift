import Foundation
import RxSwift

/// An isolated counterpart to the app's Combine search. It never runs in MovieDemo v2.
public final class RxMovieSearch {
    private let queries = PublishSubject<String>()
    private let bag = DisposeBag()

    public init(titles: [String], scheduler: SchedulerType) {
        results = queries
            .debounce(.milliseconds(250), scheduler: scheduler)
            .distinctUntilChanged()
            .map { query in
                let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return titles }
                return titles.filter { $0.localizedCaseInsensitiveContains(text) }
            }
    }

    public let results: Observable<[String]>

    public func enter(_ text: String) {
        queries.onNext(text)
    }

    public func subscribe(_ onResults: @escaping ([String]) -> Void) {
        results.subscribe(onNext: onResults).disposed(by: bag)
    }
}
