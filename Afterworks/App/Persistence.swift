import Foundation
import AfterworksCore

struct PlayerSettings: Codable, Equatable {
    var sound = true
    var haptics = true
}

struct SavedJourney: Codable {
    var version = 1
    var journey: Journey?
    var settings = PlayerSettings()
}

struct JourneyStore {
    let url: URL

    init(testing: Bool = false) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        url = support.appendingPathComponent(testing ? "Afterworks-Testing" : "Afterworks", isDirectory: true)
            .appendingPathComponent("journey.json")
    }

    var exists: Bool { FileManager.default.fileExists(atPath: url.path) }

    func load() throws -> SavedJourney? {
        guard exists else { return nil }
        let save = try JSONDecoder().decode(SavedJourney.self, from: Data(contentsOf: url))
        guard save.version == 1 else { throw SaveError.unsupportedVersion }
        if let journey = save.journey {
            try journey.validate()
        }
        return save
    }

    func save(_ save: SavedJourney) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(save).write(to: url, options: [.atomic])
    }

    func resetTestingData() throws {
        if exists { try FileManager.default.removeItem(at: url) }
    }

    enum SaveError: LocalizedError {
        case unsupportedVersion, invalidJourney
        var errorDescription: String? {
            switch self {
            case .unsupportedVersion: return "This journey was saved by a newer version. Its file has been preserved."
            case .invalidJourney: return "This saved journey could not be opened. Its file has been preserved."
            }
        }
    }
}
