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
            guard let type = parameter.type else {
                return parameter
            }
            let typeAsString = type.description
            let typeWithoutOptionalNotation = typeAsString.replacingOccurrences(of: "?", with: "")
                .replacingOccurrences(of: "!", with: "")
                .trimmingCharacters(in: .whitespaces)

            if let modifiedGenericClause = addAnyToGenericTypeArgument(type.as(SimpleTypeIdentifierSyntax.self)) {
                let typeWithModifiedGenerics = SimpleTypeIdentifierSyntax(type)?.withGenericArgumentClause(modifiedGenericClause)
                return parameter.withType(TypeSyntax(typeWithModifiedGenerics))
            }

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

    private func addAnyToGenericTypeArgument(_ type: SimpleTypeIdentifierSyntax?) -> GenericArgumentClauseSyntax? {
        guard let genericClause = type?.genericArgumentClause else {
            return nil
        }
        let arguments = genericClause.arguments.map { argument in
            let type = argument.argumentType
            let typeString = type.description
            guard protocols.contains(typeString) else {
                return argument
            }
            return argument.withArgumentType(TypeSyntax.init(stringLiteral: "any \(typeString)"))
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
                let expression = argument.expression.description.replacingOccurrences(of: type, with: "any \(type)")
                let modifiedArgument = argument.withExpression(ExprSyntax(stringLiteral: expression))
                return modifiedArgument
            }
            return argument
        }
        let modifiedArguments = TupleExprElementList(arguments)
        let modifiedNode = node.withArgumentList(modifiedArguments)
        return ExprSyntax(modifiedNode)
    }

    override func visit(_ node: GenericArgumentClauseSyntax) -> GenericArgumentClauseSyntax {
        return node
    }

    override func visit(_ node: GenericArgumentListSyntax) -> GenericArgumentListSyntax {
        return node
    }

    override func visit(_ node: SimpleTypeIdentifierSyntax) -> TypeSyntax {
        return TypeSyntax(node)
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

