import Foundation
import SwiftSyntax
import SwiftSyntaxParser

final class Processor {
    private let provider: any FileProvider
    private let finder: ProtocolFinder

    init(provider: any FileProvider = DefaultFileProvider(), finder: ProtocolFinder = ProtocolFinder(viewMode: .sourceAccurate)) {
        self.provider = provider
        self.finder = finder
    }

    func processFiles(startingAt topLevelDirectory: URL, inaccessibleProtocolDeclarations: Set<String>) throws {
        let parsedFiles = try findAllDeclaredProtocols(startingAt: topLevelDirectory)
        try annotateExistentialTypesWithAny(in: parsedFiles, inaccessibleProtocolDeclarations: inaccessibleProtocolDeclarations)
    }

    private func findAllDeclaredProtocols(startingAt topLevelDirectoryURL: URL) throws -> [URL: SourceFileSyntax] {
        let swiftFilesURLs = provider.findAllSwiftSourceFiles(at: topLevelDirectoryURL)

        var parsedFiles: [URL: SourceFileSyntax] = [:]
        for fileURL in swiftFilesURLs {
            do {
                print("Parsing", fileURL.lastPathComponent)
                let parsedFile = try SyntaxParser.parse(fileURL)
                parsedFiles[fileURL] = parsedFile
                print("Looking for declared protocols in", fileURL)
                finder.walk(parsedFile)
            } catch {
                print("Failed to parse file at: ", fileURL)
                throw error
            }
        }

        print("Found \(finder.protocols.count) declared protocols in \(swiftFilesURLs.count) files")
        return parsedFiles
    }

    private func annotateExistentialTypesWithAny(in parsedFiles: [URL: SourceFileSyntax], inaccessibleProtocolDeclarations: Set<String>) throws {
        var protocols = inaccessibleProtocolDeclarations
        protocols.formUnion(finder.protocols)
        let annotator = Annotator(protocols: protocols)
        var annotationCounter = 0

        for (fileURL, file) in parsedFiles {
            let modifiedSource = annotator.visit(file)
            if file != modifiedSource {
                var outputStream = ""
                modifiedSource.write(to: &outputStream)

                do {
                    print("Annotating: ", fileURL.lastPathComponent)
                    try outputStream.write(to: fileURL, atomically: true, encoding: .utf8)
                    annotationCounter += 1
                } catch {
                    print("Failed to annotate: \(fileURL)")
                    throw error
                }
            }
        }

        print("\nAnnotated \(annotationCounter) files")
    }
}
