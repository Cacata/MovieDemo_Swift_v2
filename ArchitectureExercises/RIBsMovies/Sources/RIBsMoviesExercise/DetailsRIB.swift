import RIBs
import UIKit

protocol DetailsDependency: Dependency {}

final class DetailsBuilder: Builder<DetailsDependency> {
    func build(title: String, listener: DetailsListener) -> DetailsRouting {
        let view = DetailsViewController(title: title)
        let interactor = DetailsInteractor(presenter: view)
        interactor.listener = listener
        return DetailsRouter(interactor: interactor, viewController: view)
    }
}

protocol DetailsRouting: ViewableRouting {}
protocol DetailsListener: AnyObject { func detailsClosed() }
protocol DetailsPresentable: Presentable { var listener: DetailsPresentableListener? { get set } }
protocol DetailsPresentableListener: AnyObject { func closeTapped() }
protocol DetailsInteractable: Interactable { var router: DetailsRouting? { get set } }

final class DetailsInteractor: PresentableInteractor<DetailsPresentable>, DetailsInteractable, DetailsPresentableListener {
    weak var router: DetailsRouting?
    weak var listener: DetailsListener?

    override init(presenter: DetailsPresentable) {
        super.init(presenter: presenter)
        presenter.listener = self
    }

    func closeTapped() { listener?.detailsClosed() }
}

final class DetailsRouter: ViewableRouter<DetailsInteractable, DetailsViewController>, DetailsRouting {
    override init(interactor: DetailsInteractable, viewController: DetailsViewController) {
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }
}

final class DetailsViewController: UIViewController, DetailsPresentable, ViewControllable {
    weak var listener: DetailsPresentableListener?
    private let movieTitle: String

    init(title: String) {
        movieTitle = title
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Use init(title:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = movieTitle
        let button = UIButton(type: .system)
        button.setTitle("Close Details", for: .normal)
        button.addTarget(self, action: #selector(close), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [label, button])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    @objc private func close() { listener?.closeTapped() }
}
