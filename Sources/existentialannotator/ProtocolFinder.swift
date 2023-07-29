import Foundation
import SwiftSyntax

final class ProtocolFinder: SyntaxVisitor {
    private(set)var protocols: Set<String> = []

    override func visitPost(_ node: ProtocolDeclSyntax) {
        protocols.insert(node.identifier.text)
    }
}
