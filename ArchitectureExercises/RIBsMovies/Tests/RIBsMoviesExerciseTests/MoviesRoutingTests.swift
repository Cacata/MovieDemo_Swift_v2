import RIBs
import UIKit
import XCTest
@testable import RIBsMoviesExercise

final class MoviesRoutingTests: XCTestCase {
    func testDetailsChildAttachesAndDetaches() {
        let router = MoviesBuilder(dependency: ExerciseAppDependency()).build() as! MoviesRouter
        let window = UIWindow()
        router.launch(from: window)

        let movies = router.interactable as! MoviesInteractor
        movies.selectedMovie(title: "Interstellar")
        XCTAssertEqual(router.children.count, 1)
        XCTAssertTrue(router.children[0].interactable.isActive)

        let details = router.children[0].interactable as! DetailsInteractor
        details.closeTapped()
        XCTAssertTrue(router.children.isEmpty)
        XCTAssertFalse(details.isActive)
    }
}
