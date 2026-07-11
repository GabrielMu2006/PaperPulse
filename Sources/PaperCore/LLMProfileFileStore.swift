import Foundation

public enum LLMProfileFileStoreError: Error, Equatable {
    case fileSystem(String)
}

public struct LLMProfileFileStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func loadConfigurations() throws -> [LLMProfileConfiguration] {
        do {
            guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            let configurations = try files
                .filter { $0.pathExtension.lowercased() == "json" }
                .map { try JSONDecoder().decode(LLMProfileConfiguration.self, from: Data(contentsOf: $0)) }
            return configurations.sorted { lhs, rhs in
                let comparison = lhs.model.localizedCaseInsensitiveCompare(rhs.model)
                return comparison == .orderedSame
                    ? lhs.id.uuidString < rhs.id.uuidString
                    : comparison == .orderedAscending
            }
        } catch {
            throw LLMProfileFileStoreError.fileSystem(error.localizedDescription)
        }
    }

    public func save(_ configuration: LLMProfileConfiguration) throws {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try removeFiles(matching: configuration.id)
            let destination = fileURL(for: configuration)
            try JSONEncoder().encode(configuration).write(to: destination, options: [.atomic])
        } catch let error as LLMProfileFileStoreError {
            throw error
        } catch {
            throw LLMProfileFileStoreError.fileSystem(error.localizedDescription)
        }
    }

    public func delete(_ configuration: LLMProfileConfiguration) throws {
        do {
            try removeFiles(matching: configuration.id)
        } catch let error as LLMProfileFileStoreError {
            throw error
        } catch {
            throw LLMProfileFileStoreError.fileSystem(error.localizedDescription)
        }
    }

    public func fileURL(for configuration: LLMProfileConfiguration) -> URL {
        directory.appendingPathComponent(
            "\(safeFilenameStem(configuration.model))-\(configuration.id.uuidString.lowercased()).json"
        )
    }

    private func removeFiles(matching id: UUID) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        for file in files where file.pathExtension.lowercased() == "json" {
            guard let stored = try? JSONDecoder().decode(LLMProfileConfiguration.self, from: Data(contentsOf: file)),
                  stored.id == id else {
                continue
            }
            try FileManager.default.removeItem(at: file)
        }
    }

    private func safeFilenameStem(_ model: String) -> String {
        let mapped = model.lowercased().map { character -> Character in
            character.isLetter || character.isNumber || character == "." || character == "-" ? character : "-"
        }
        let collapsed = String(mapped).split(separator: "-").joined(separator: "-")
        return collapsed.isEmpty ? "model" : collapsed
    }
}
