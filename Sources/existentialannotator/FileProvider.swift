import Foundation

protocol FileProvider {
    func findAllSwiftSourceFiles(at url: URL) -> [URL]
}
