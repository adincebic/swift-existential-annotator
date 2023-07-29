import ArgumentParser
import SwiftSyntax
import SwiftSyntaxParser
import Foundation

@main
struct RootDirectory: ParsableCommand {
    @Argument(help: "Top-level directory where Swift files are located", transform: {
        let string = $0 == "." ? FileManager.default.currentDirectoryPath : $0
        return URL(string: string)!
    })
    var rootDirectory: URL

    func run() throws {
        let processor = Processor()

        try processor.processFiles(startingAt: rootDirectory)
    }
}
