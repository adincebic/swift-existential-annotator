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

    override func visit(_ node: VariableDeclSyntax) -> DeclSyntax {
        let isLazy = node.modifiers?.tokens(viewMode: .sourceAccurate).contains(where: { token in
            token.tokenKind == .contextualKeyword("lazy")
        })

        let tokens = node.tokens(viewMode: .sourceAccurate).map({$0.description.trimmingCharacters(in: .whitespaces)})
        guard let type = tokens.first(where: { protocols.contains($0)}) else {
            return DeclSyntax(node)
        }

        let spaceOrEmptyString = isLazy == true ? " " : ""
        let typeWithAnyKeyword = "any \(type)\(spaceOrEmptyString)"
        let isOptional = node.tokens(viewMode: .sourceAccurate).contains(where: { token in
            token.tokenKind == .postfixQuestionMark
        })

        var variableDeclarationString: String {
            if isOptional == true {
                return node.description.replacingOccurrences(of: ": \(type)?", with: ": (\(typeWithAnyKeyword))?")
            }
            return node.description.replacingOccurrences(of: ": \(type)\(spaceOrEmptyString)", with: ": \(typeWithAnyKeyword)")
        }
        return DeclSyntax(stringLiteral: variableDeclarationString)
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
