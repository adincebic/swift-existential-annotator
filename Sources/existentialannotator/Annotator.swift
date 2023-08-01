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
        let rawTokens = node.tokens(viewMode: .sourceAccurate)
        let tokens = Set(rawTokens.map { $0.description.trimmingCharacters(in: .whitespaces) })
        guard let type = tokens.first(where: { protocols.contains($0) }) else {
            return DeclSyntax(node)
        }
        if tokens.contains("as") {
            return addAnyToCastedExistential(type: type, node: node)
        }
        let spaceOrEmptyString = isLazy == true ? " " : ""
        let typeWithAnyKeyword = "any \(type)\(spaceOrEmptyString)"

        let optionalTypeAttributes = isOptional(tokens: rawTokens)
        let isOptional = optionalTypeAttributes.isOptional
        let optionalNotation = optionalTypeAttributes.optionalNotation

        var variableDeclarationString: String {
            if isOptional {
                return node.description.replacingOccurrences(of: ": \(type)\(optionalNotation)", with: ": (\(typeWithAnyKeyword))\(optionalNotation)")
            }
            return node.description.replacingOccurrences(of: ": \(type)\(spaceOrEmptyString)", with: ": \(typeWithAnyKeyword)")
        }
        return DeclSyntax(stringLiteral: variableDeclarationString)
    }

    private func addAnyToCastedExistential(type: String, node: VariableDeclSyntax) -> DeclSyntax {
        let rawString = node.description
            .replacingOccurrences(of: type, with: "any \(type)")
        return DeclSyntax(stringLiteral: rawString)
    }

    override func visit(_ node: ParameterClauseSyntax) -> ParameterClauseSyntax {
        let parameters = node.parameterList.map { parameter in
            guard let type = parameter.type?.description else {
                return parameter
            }
            let typeWithoutOptionalNotation = type.replacingOccurrences(of: "?", with: "")
                .replacingOccurrences(of: "!", with: "")
                .trimmingCharacters(in: .whitespaces)
            guard protocols.contains(typeWithoutOptionalNotation) else {
                return parameter
            }
            let optionalAttributes = isOptional(tokens: parameter.tokens(viewMode: .sourceAccurate))
            if optionalAttributes.isOptional {
                return parameter.withType(TypeSyntax(stringLiteral: "(any \(typeWithoutOptionalNotation))\(optionalAttributes.optionalNotation)"))
            }
            return parameter.withUnexpectedBetweenColonAndType(anyToken)
        }
        let modifiedParameterList = FunctionParameterListSyntax(parameters)
        let nodeWithModifiedParameterList = node.withParameterList(modifiedParameterList)
        return nodeWithModifiedParameterList
    }

    private func isOptional(tokens: TokenSequence) -> (isOptional: Bool, optionalNotation: String) {
        let token = tokens.first(where: {
            $0.tokenKind == .postfixQuestionMark || $0.tokenKind == .exclamationMark
        })
        let notation = token?.description ?? ""
        let isOptional = !notation.isEmpty
        return (isOptional: isOptional, optionalNotation: notation)
    }
}
