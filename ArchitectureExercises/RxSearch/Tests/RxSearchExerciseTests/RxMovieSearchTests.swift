import RxTest
import XCTest
@testable import RxSearchExercise

final class RxMovieSearchTests: XCTestCase {
    func testDebounceEmitsOnlyLatestQueryAndMatchesTitles() {
        let scheduler = TestScheduler(initialClock: 0, resolution: 0.001)
        let search = RxMovieSearch(titles: ["Alien", "Aliens", "Interstellar"], scheduler: scheduler)
        var outputs: [[String]] = []
        search.subscribe { outputs.append($0) }

        search.enter("A")
        scheduler.advanceTo(100)
        search.enter("Ali")
        scheduler.advanceTo(349)
        XCTAssertTrue(outputs.isEmpty)
        scheduler.advanceTo(351)
        XCTAssertEqual(outputs, [["Alien", "Aliens"]])

        search.enter("")
        scheduler.advanceTo(601)
        XCTAssertEqual(outputs.last, ["Alien", "Aliens", "Interstellar"])
    }
}
