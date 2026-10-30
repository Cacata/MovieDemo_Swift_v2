import RIBs
import UIKit

// Feature tree: Movies (root) -> Details (attached only while a movie is open).
public final class ExerciseAppDependency: Dependency {
    public init() {}
}

public protocol MoviesDependency: Dependency {}
extension ExerciseAppDependency: MoviesDependency {}

final class MoviesComponent: Component<MoviesDependency>, DetailsDependency {}

public final class MoviesBuilder: Builder<MoviesDependency> {
    public func build() -> LaunchRouting {
        let view = MoviesViewController()
        let interactor = MoviesInteractor(presenter: view)
        let detailsBuilder = DetailsBuilder(dependency: MoviesComponent(dependency: dependency))
        return MoviesRouter(interactor: interactor, viewController: view, detailsBuilder: detailsBuilder)
    }
}

protocol MoviesRouting: ViewableRouting {
    func routeToDetails(title: String)
    func closeDetails()
}

protocol MoviesPresentable: Presentable {
    var listener: MoviesPresentableListener? { get set }
}

protocol MoviesPresentableListener: AnyObject {
    func selectedMovie(title: String)
}

protocol MoviesInteractable: Interactable, DetailsListener {
    var router: MoviesRouting? { get set }
}

final class MoviesInteractor: PresentableInteractor<MoviesPresentable>, MoviesInteractable, MoviesPresentableListener {
    weak var router: MoviesRouting?

    override init(presenter: MoviesPresentable) {
        super.init(presenter: presenter)
        presenter.listener = self
    }

    func selectedMovie(title: String) { router?.routeToDetails(title: title) }
    func detailsClosed() { router?.closeDetails() }
}

protocol MoviesViewControllable: ViewControllable {
    func showDetails(_ child: ViewControllable)
    func hideDetails()
}

final class MoviesRouter: LaunchRouter<MoviesInteractable, MoviesViewControllable>, MoviesRouting {
    private let detailsBuilder: DetailsBuilder
    private var details: DetailsRouting?

    init(interactor: MoviesInteractable, viewController: MoviesViewControllable, detailsBuilder: DetailsBuilder) {
        self.detailsBuilder = detailsBuilder
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }

    func routeToDetails(title: String) {
        guard details == nil else { return }
        let child = detailsBuilder.build(title: title, listener: interactor)
        details = child
        attachChild(child)
        viewController.showDetails(child.viewControllable)
    }

    func closeDetails() {
        guard let details else { return }
        viewController.hideDetails()
        detachChild(details)
        self.details = nil
    }
}

final class MoviesViewController: UIViewController, MoviesPresentable, MoviesViewControllable {
    weak var listener: MoviesPresentableListener?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let button = UIButton(type: .system)
        button.setTitle("Open Interstellar", for: .normal)
        button.addTarget(self, action: #selector(openMovie), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    @objc private func openMovie() { listener?.selectedMovie(title: "Interstellar") }
    func showDetails(_ child: ViewControllable) { present(child.uiviewController, animated: false) }
    func hideDetails() { dismiss(animated: false) }
}
