import XCTest
import SwiftSyntaxParser
@testable import existentialannotator

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

    func testThatSourceIsUntouchedWhenThereAreNoDetectedExistentials()  throws{
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

    func testThatExistentialIsAnnotatedInMoreComplexType() throws {
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
}
