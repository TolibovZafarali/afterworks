import Foundation
import AfterworksCore

struct PlayerSettings: Codable, Equatable {
    var sound = true
    var haptics = true
}

struct SavedCampaign: Codable {
    var version = 2
    var campaign: Campaign
    var settings = PlayerSettings()
}

struct LoadedCampaign {
    var save: SavedCampaign
    var importedSettings = false
}

struct CampaignStore {
    let url: URL
    let legacyURL: URL

    init(testing: Bool = false) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = support.appendingPathComponent(testing ? "Afterworks-Testing" : "Afterworks", isDirectory: true)
        url = directory.appendingPathComponent("campaign.json")
        legacyURL = directory.appendingPathComponent("journey.json")
    }

    func load() throws -> LoadedCampaign? {
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            let header = try JSONDecoder().decode(SaveHeader.self, from: data)
            guard header.version == 2 else { throw SaveError.unsupportedVersion }
            let save = try JSONDecoder().decode(SavedCampaign.self, from: data)
            try save.campaign.validate()
            return LoadedCampaign(save: save)
        }
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            // The earlier island remains untouched; only compatible preferences carry forward.
            let settings = (try? JSONDecoder().decode(LegacyPreferences.self, from: Data(contentsOf: legacyURL)))?.settings ?? PlayerSettings()
            return LoadedCampaign(save: SavedCampaign(campaign: .new, settings: settings), importedSettings: true)
        }
        return nil
    }

    func save(_ save: SavedCampaign) throws {
        try save.campaign.validate()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(save).write(to: url, options: [.atomic])
    }

    func resetTestingData() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    func preserveUnreadableSave() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let backup = url.deletingLastPathComponent().appendingPathComponent("campaign-preserved-\(UUID().uuidString).json")
        try FileManager.default.copyItem(at: url, to: backup)
    }

    private struct SaveHeader: Decodable { let version: Int }
    private struct LegacyPreferences: Decodable { let settings: PlayerSettings }

    enum SaveError: LocalizedError {
        case unsupportedVersion
        var errorDescription: String? { "This progress file uses another save version. Its contents have been preserved." }
    }
}
