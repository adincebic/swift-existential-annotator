import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

final class Annotator: SyntaxRewriter {
    private let protocols: Set<String>

    init(protocols: Set<String>) {
        self.protocols = protocols
    }

    @UnexpectedNodesBuilder
    private var anyToken: UnexpectedNodesSyntax {
        TokenSyntax(.unknown("any"), trailingTrivia: [.spaces(1)], presence: .present)
    }

    override func visit(_ node: TypeAnnotationSyntax) -> TypeAnnotationSyntax {
        guard protocols.contains(node.type.description) else { return node }
        let annotatedWithAny = node.withUnexpectedBetweenColonAndType(anyToken)
        return annotatedWithAny
    }

    override func visit(_ node: ParameterClauseSyntax) -> ParameterClauseSyntax {
        let parameters = node.parameterList.map { parameter in
            if let type = parameter.type?.description, protocols.contains(type.trimmingCharacters(in: .whitespaces)) {
                return parameter.withUnexpectedBetweenColonAndType(anyToken)
            }
            return parameter
        }
        let modifiedParameterList = FunctionParameterListSyntax(parameters)
        let nodeWithModifiedParameterList = node.withParameterList(modifiedParameterList)
        return nodeWithModifiedParameterList
    }
}
