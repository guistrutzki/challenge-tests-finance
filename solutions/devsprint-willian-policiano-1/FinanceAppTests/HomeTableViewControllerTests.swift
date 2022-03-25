import XCTest
import Core
import UIKit

// SUT

class HomeTableViewController: UITableViewController {
    private let service: HomeLoader

    init(service: HomeLoader) {
        self.service = service
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        refreshControl = UIRefreshControl()
        refreshControl?.beginRefreshing()

        service.getHome { [weak self] result in
            self?.refreshControl?.endRefreshing()

            switch result {
            case .success: break
            case .failure:
                let alert = UIAlertController()
                self?.present(alert, animated: true)
            }
        }
    }
}

// Test Doubles

class HomeLoaderSpy: HomeLoader {
    var getHomeCallsCount: Int {
        completions.count
    }

    private(set) var completions: [(HomeLoader.Result) -> Void] = []

    func getHome(completion: @escaping (HomeLoader.Result) -> Void) {
        completions.append(completion)
    }

    func completeWithFailure(_ error: Error) {
        completions[0](.failure(error))
    }

    func completeWithSuccess(_ data: Home) {
        completions[0](.success(data))
    }
}

// Test

class HomeTableViewControllerTests: XCTestCase {
    func test_initShouldNotPerformAnyRequest() {
        let (_, service) = makeSUT()

        XCTAssertEqual(service.getHomeCallsCount, 0)
    }

    func test_showLoadingOnRender() {
        let (sut, _) = makeSUT()

        sut.render()

        XCTAssertTrue(sut.isRefreshing)
    }

    func test_hideLoadingAfterFailure() {
        let (sut, service) = makeSUT()

        sut.render()
        service.completeWithFailure(anyError)

        XCTAssertFalse(sut.isRefreshing)
    }

    func test_showsErrorDialogOnFailure() {
        let (sut, service) = makeSUT()

        sut.render()
        service.completeWithFailure(anyError)

        XCTAssertNotNil(sut.presentedError)
    }

    func test_doesNotShowErrorDialogOnSuccess() {
        let (sut, service) = makeSUT()

        sut.render()
        service.completeWithSuccess(Home(balance: 123, savings: 321, spending: 213))

        XCTAssertNil(sut.presentedError)
    }

    // MARK: Helpers

    private var anyError: NSError {
        NSError(domain: UUID().uuidString, code: 0, userInfo: nil)
    }

    private func makeSUT(file: StaticString = #file, line: UInt = #line) -> (TestableHomeTableViewController, HomeLoaderSpy) {
        let service = HomeLoaderSpy()
        let sut = TestableHomeTableViewController(service: service)

        trackForMemoryLeak(sut, file: file, line: line)
        trackForMemoryLeak(service, file: file, line: line)

        return (sut, service)
    }

    private func trackForMemoryLeak(_ instance: AnyObject, file: StaticString = #file, line: UInt = #line) {

        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
        }
    }
}

class TestableHomeTableViewController: HomeTableViewController {
    private(set) var presentedViewControllers: [UIViewController] = []

    func render() {
        beginAppearanceTransition(true, animated: false)
    }

    var isRefreshing: Bool {
        refreshControl?.isRefreshing == true
    }

    var presentedError: UIAlertController? {
        presentedViewControllers.last as? UIAlertController
    }

    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        presentedViewControllers.append(viewControllerToPresent)
//        super.present(viewControllerToPresent, animated: false, completion: completion)
    }
}