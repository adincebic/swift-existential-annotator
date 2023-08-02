@testable import existentialannotator
import SwiftSyntaxParser
import XCTest

final class ExistentialAnnotatorTests: XCTestCase {
    func testThatExistentialIsAnnotated() throws {
        let exampleFile = #"""
        final class SimpleUseCase {
          private let repository: ArticleRepository
          private var article: Article!

          init(repository: ArticleRepository) {
            self.repository = repository
          }
        }
        """#
        let sut = Annotator(protocols: ["ArticleRepository"])
        let parsedSource = try SyntaxParser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SimpleUseCase {
          private let repository: any ArticleRepository
          private var article: Article!

          init(repository: any ArticleRepository) {
            self.repository = repository
          }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatMultipleExistentialsAreAnnotated() throws {
        let exampleFile = #"""
        final class SimpleUseCase {
          private let repository: ArticleRepository
          private let featureFlags: FeatureFlagsProvider
          private var article: Article!

          init(repository: ArticleRepository, featureFlags: FeatureFlagsProvider) {
            self.repository = repository
            self.featureFlags = featureFlags
          }
        }
        """#
        let sut = Annotator(protocols: ["ArticleRepository", "FeatureFlagsProvider"])
        let parsedSource = try SyntaxParser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SimpleUseCase {
          private let repository: any ArticleRepository
          private let featureFlags: any FeatureFlagsProvider
          private var article: Article!

          init(repository: any ArticleRepository, featureFlags: any FeatureFlagsProvider) {
            self.repository = repository
            self.featureFlags = featureFlags
          }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatSourceIsUntouchedWhenThereAreNoDetectedExistentials() throws {
        let exampleFile = #"""
        final class SimpleUseCase {
          private let repository: ArticleRepository
          private let featureFlags: FeatureFlagsProvider
          private var article: Article!

          init(repository: ArticleRepository, featureFlags: FeatureFlagsProvider) {
            self.repository = repository
            self.featureFlags = featureFlags
          }
        }
        """#
        let sut = Annotator(protocols: [])
        let parsedSource = try SyntaxParser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SimpleUseCase {
          private let repository: ArticleRepository
          private let featureFlags: FeatureFlagsProvider
          private var article: Article!

          init(repository: ArticleRepository, featureFlags: FeatureFlagsProvider) {
            self.repository = repository
            self.featureFlags = featureFlags
          }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedAsParameterInPresenceOfDefaultArgument() throws {
        let exampleFile = #"""
        final class SurveyViewModel: ObservableObject {
            private var survey: Survey
            private let useCase: SurveyUseCase
            @Published var isLoading = false

            init(survey: Survey,
                 useCase: SurveyUseCase = DefaultSurveyUseCase()) {
                self.survey = survey
                self.useCase = useCase
            }
        }
        """#
        let sut = Annotator(protocols: ["SurveyUseCase"])
        let parsedSource = try SyntaxParser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SurveyViewModel: ObservableObject {
            private var survey: Survey
            private let useCase: any SurveyUseCase
            @Published var isLoading = false

            init(survey: Survey,
                 useCase: any SurveyUseCase = DefaultSurveyUseCase()) {
                self.survey = survey
                self.useCase = useCase
            }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedWithLazyProperty() throws {
        let exampleFile = #"""
        final class SurveyViewModel: ObservableObject {
            private lazy var useCase: SurveyUseCase = DefaultSurveyUseCase()
            @Published var isLoading = false

            init(survey: Survey) {
                self.survey = survey
            }
        }
        """#
        let sut = Annotator(protocols: ["SurveyUseCase"])
        let parsedSource = try SyntaxParser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SurveyViewModel: ObservableObject {
            private lazy var useCase: any SurveyUseCase = DefaultSurveyUseCase()
            @Published var isLoading = false

            init(survey: Survey) {
                self.survey = survey
            }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenItIsOptional() throws {
        let exampleFile = #"""
        final class SurveyViewModel: ObservableObject {
            private lazy var useCase: SurveyUseCase = DefaultSurveyUseCase()
            weak var delegate: SurveyDelegate?
            @Published var isLoading = false

            init(survey: Survey) {
                self.survey = survey
            }
        }
        """#
        let sut = Annotator(protocols: ["SurveyUseCase", "SurveyDelegate"])
        let parsedSource = try SyntaxParser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SurveyViewModel: ObservableObject {
            private lazy var useCase: any SurveyUseCase = DefaultSurveyUseCase()
            weak var delegate: (any SurveyDelegate)?
            @Published var isLoading = false

            init(survey: Survey) {
                self.survey = survey
            }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenItIsImplicitlyUnwrappedOptional() throws {
        let exampleFile = #"""
        final class SurveyViewModel: ObservableObject {
            private lazy var useCase: SurveyUseCase = DefaultSurveyUseCase()
            weak var delegate: SurveyDelegate!
            @Published var isLoading = false

            init(survey: Survey) {
                self.survey = survey
            }
        }
        """#
        let sut = Annotator(protocols: ["SurveyUseCase", "SurveyDelegate"])
        let parsedSource = try SyntaxParser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SurveyViewModel: ObservableObject {
            private lazy var useCase: any SurveyUseCase = DefaultSurveyUseCase()
            weak var delegate: (any SurveyDelegate)!
            @Published var isLoading = false

            init(survey: Survey) {
                self.survey = survey
            }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenItIsOptionalInFunctionParameter() throws {
        let exampleFile = #"""
        final class SurveyViewModel: ObservableObject {
            weak var delegate: SurveyDelegate!
            @Published var isLoading = false

            func setDelegate(delegate: SurveyDelegate?) {
                print(delegate)
            }
        }
        """#
        let sut = Annotator(protocols: ["SurveyUseCase", "SurveyDelegate"])
        let parsedSource = try SyntaxParser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SurveyViewModel: ObservableObject {
            weak var delegate: (any SurveyDelegate)!
            @Published var isLoading = false

            func setDelegate(delegate: (any SurveyDelegate)?) {
                print(delegate)
            }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenItIsImplicitlyUnwrappedOptionalInFunctionParameter() throws {
        let exampleFile = #"""
        final class SurveyViewModel: ObservableObject {
            weak var delegate: SurveyDelegate!
            @Published var isLoading = false

            func setDelegate(delegate: SurveyDelegate!) {
                print(delegate)
            }
        }
        """#
        let sut = Annotator(protocols: ["SurveyUseCase", "SurveyDelegate"])
        let parsedSource = try SyntaxParser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        final class SurveyViewModel: ObservableObject {
            weak var delegate: (any SurveyDelegate)!
            @Published var isLoading = false

            func setDelegate(delegate: (any SurveyDelegate)!) {
                print(delegate)
            }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenCastingOnAssignment() throws {
        let exampleFile = #"""
        struct MyType {
            var isSent: Bool {
                get {
                    return true
                }
                set {
                    let newValue = newValue as NSCoding
                    print(newValue)
                }
            }
        }
        """#

        let sut = Annotator(protocols: ["NSCoding"])
        let parsedSource = try SyntaxParser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        struct MyType {
            var isSent: Bool {
                get {
                    return true
                }
                set {
                    let newValue = newValue as any NSCoding
                    print(newValue)
                }
            }
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenCastingArgumentInMethodCall() throws {
        let exampleFile = #"""
        struct MyType {
            init() {
                let string = ""
                open(string as! Survey)
            }

            func open(_ survey: Survey) {}
        }
        """#

        let sut = Annotator(protocols: ["Survey"])
        let parsedSource = try SyntaxParser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        struct MyType {
            init() {
                let string = ""
                open(string as! any Survey)
            }

            func open(_ survey: any Survey) {}
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }

    func testThatExistentialIsAnnotatedWhenUsedForGenericSpecialization() throws {
        let exampleFile = #"""
        func controllerDidChangeContent(_: NSFetchedResultsController<NSFetchRequestResult>) {
            //
        }
        """#
        let sut = Annotator(protocols: ["NSFetchRequestResult"])
        let parsedSource = try SyntaxParser.parse(source: exampleFile)

        let annotated = sut.visit(parsedSource)

        let expected = #"""
        func controllerDidChangeContent(_: NSFetchedResultsController<any NSFetchRequestResult>) {
            //
        }
        """#

        XCTAssertEqual(annotated.description, expected)
    }
}
