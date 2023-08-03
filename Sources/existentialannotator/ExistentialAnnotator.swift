import ArgumentParser
import Foundation
import SwiftSyntax
import SwiftSyntaxParser

@main
struct RootDirectory: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(abstract: "existentialannotator marks all Swift existential types with `any` keyword.")
    }

    @Argument(help: "Top-level directory where Swift files are located", transform: {
        let string = $0 == "." ? FileManager.default.currentDirectoryPath : $0
        return URL(string: string)!
    })
    var rootDirectory: URL

    private var commonlyUsedSystemProtocols: Set<String> {
        [
            "Codable",
            "Encodable",
            "Decodable",
            "NSFetchRequestResult",
            "NSCoding",
        ]
    }

    func run() throws {
        let processor = Processor()

        try processor.processFiles(startingAt: rootDirectory, inaccessibleProtocolDeclarations: commonlyUsedSystemProtocols)
    }
}
