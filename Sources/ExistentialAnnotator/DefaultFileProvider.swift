import Foundation

final class DefaultFileProvider: FileProvider {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func findAllSwiftSourceFiles(at url: URL) -> [URL] {
        var files = [URL]()

        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: nil, options: options)
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.hasDirectoryPath {
                files += findAllSwiftSourceFiles(at: fileURL)
            } else if fileURL.pathExtension == "swift" {
                files.append(fileURL)
            }
        }
        return files
    }
}
