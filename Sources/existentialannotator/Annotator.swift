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
        let rawTokens = node.tokens(viewMode: .sourceAccurate)
        let tokens = Set(rawTokens.map { $0.description.trimmingCharacters(in: .whitespaces) })
        guard let type = tokens.first(where: { protocols.contains($0) }) else {
            return DeclSyntax(node)
        }

        if node.description.contains("as \(type)") {
            return addAnyToCastedExistential(type: type, node: node)
        }

        let typeWithAnyKeyword = withExistentialAny(type)
        let optionalTypeAttributes = isOptional(tokens: rawTokens)
        let isOptional = optionalTypeAttributes.isOptional
        let optionalNotation = optionalTypeAttributes.optionalNotation

        var variableDeclarationString: String {
            let colonToken = TokenSyntax(.colon, trailingTrivia: [.spaces(1)], presence: .present).description
            if isOptional {
                return node.description.replacingOccurrences(of: "\(colonToken)\(type)\(optionalNotation)", with: "\(colonToken)(\(typeWithAnyKeyword))\(optionalNotation)")
            } else if node.typeUsedInArraySyntax(type) {
                return node.description.replacingOccurrences(of: "[\(type)]", with: "[\(withExistentialAny(type))]")
            }
            return node.description.replacingOccurrences(of: "\(colonToken)\(type)", with: "\(colonToken)\(typeWithAnyKeyword)")
        }
        return DeclSyntax(stringLiteral: variableDeclarationString)
    }

    private func addAnyToCastedExistential(type: String, node: VariableDeclSyntax) -> DeclSyntax {
        let rawString = node.description
            .replacingOccurrences(of: " \(type)", with: " \(withExistentialAny(type))")
        return DeclSyntax(stringLiteral: rawString)
    }

    override func visit(_ node: ParameterClauseSyntax) -> ParameterClauseSyntax {
        let parameters = node.parameterList.map { parameter in
            guard let type = parameter.type else {
                return parameter
            }
            let typeAsString = type.rawStringRepresentation

            if let modifiedGenericClause = addAnyToGenericTypeArgument(type.as(SimpleTypeIdentifierSyntax.self)) {
                let typeWithModifiedGenerics = SimpleTypeIdentifierSyntax(type)?.withGenericArgumentClause(modifiedGenericClause)
                return parameter.withType(TypeSyntax(typeWithModifiedGenerics))
            }

            guard protocols.contains(typeAsString) else {
                return parameter
            }

            let optionalAttributes = isOptional(tokens: parameter.tokens(viewMode: .sourceAccurate))
            if optionalAttributes.isOptional {
                let modifiedType = withExistentialAny(type)
                    .withLeadingTrivia([.unexpectedText("(")])
                    .withTrailingTrivia([.unexpectedText(")\(optionalAttributes.optionalNotation)")])

                return parameter.withType(modifiedType)
            }
            return parameter.withUnexpectedBetweenColonAndType(anyToken)
        }

        let modifiedParameterList = FunctionParameterListSyntax(parameters)
        let nodeWithModifiedParameterList = node.withParameterList(modifiedParameterList)
        return nodeWithModifiedParameterList
    }

    private func addAnyToGenericTypeArgument(_ type: SimpleTypeIdentifierSyntax?) -> GenericArgumentClauseSyntax? {
        guard let genericClause = type?.genericArgumentClause else {
            return nil
        }
        let arguments = genericClause.arguments.map { argument in
            let type = argument.argumentType
            let typeString = type.rawStringRepresentation
            guard protocols.contains(typeString) else {
                return argument
            }
            let typeWithAnyKeyword = withExistentialAny(type)
            return argument.withArgumentType(typeWithAnyKeyword)
        }
        let modifiedArguments = GenericArgumentListSyntax(arguments)
        let modifiedGenericClause = genericClause.withArguments(modifiedArguments)
        return modifiedGenericClause
    }

    override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        let arguments = node.argumentList.map { argument in
            let tokens = argument.tokens(viewMode: .sourceAccurate)
            guard let type = tokens.first(where: { token in
                let token = token.description.trimmingCharacters(in: .whitespaces)
                return protocols.contains(token)
            })?.description else { return argument }
            if tokens.contains(where: { $0.tokenKind == .asKeyword }) {
                let expression = argument.expression.description.replacingOccurrences(of: type, with: withExistentialAny(type))
                let modifiedArgument = argument.withExpression(ExprSyntax(stringLiteral: expression))
                return modifiedArgument
            }
            return argument
        }
        let modifiedArguments = TupleExprElementList(arguments)
        let modifiedNode = node.withArgumentList(modifiedArguments)
        return ExprSyntax(modifiedNode)
    }

    override func visit(_ node: ReturnClauseSyntax) -> ReturnClauseSyntax {
        if let compositionSyntax = node.returnType.as(CompositionTypeSyntax.self) {
            let modifiedReturnType = TypeSyntax(compositionSyntax.withUnexpectedBeforeElements(anyToken))
            return node.withReturnType(modifiedReturnType)
        }
        guard protocols.contains(node.returnType.rawStringRepresentation) else {
            return node
        }
        let currentTypeWithoutAnyKeyword = node.returnType

        var typeWithAnyKeyword: TypeSyntax {
            if let lastToken = currentTypeWithoutAnyKeyword.lastToken, lastToken.isOptionalNotation {
                let typeString = "(\(withExistentialAny(currentTypeWithoutAnyKeyword.rawStringRepresentation)))\(lastToken.description)"
                return TypeSyntax(stringLiteral: typeString)
            }
            return withExistentialAny(currentTypeWithoutAnyKeyword)
                .withTrailingTrivia([.spaces(1)])
        }

        let modifiedNode = node.withReturnType(typeWithAnyKeyword)
        return modifiedNode
    }

    private func isOptional(tokens: TokenSequence) -> (isOptional: Bool, optionalNotation: String) {
        let token = tokens.first(where: { $0.isOptionalNotation })
        let notation = token?.description ?? ""
        let isOptional = !notation.isEmpty
        return (isOptional: isOptional, optionalNotation: notation)
    }

    private func withExistentialAny(_ type: TypeSyntax) -> TypeSyntax {
        let typeWithAny = TypeSyntax(stringLiteral: withExistentialAny(type.rawStringRepresentation))
        return typeWithAny
    }

    private func withExistentialAny(_ type: String) -> String {
        "any \(type)"
    }
}

private extension TypeSyntax {
    var rawStringRepresentation: String {
        let string = description.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "!", with: "")
        return string
    }
}

extension VariableDeclSyntax {
    func typeUsedInArraySyntax(_ type: String) -> Bool {
        return description.contains("[\(type)]")
    }
}

private extension TokenSyntax {
    var isOptionalNotation: Bool {
        tokenKind == .postfixQuestionMark || tokenKind == .exclamationMark
    }
}
