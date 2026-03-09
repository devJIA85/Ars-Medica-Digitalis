//
//  ClinicalScale.swift
//  Ars Medica Digitalis
//
//  Modelos genéricos de escalas clínicas cargadas desde JSON.
//

import CryptoKit
import Foundation

struct ClinicalScale: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let domain: String
    let name: String
    let description: String
    let timeframe: ScaleTimeframe
    let meta: ScaleMeta?
    let items: [ScaleItem]
    let scoring: ScaleScoring

    init(
        id: String,
        domain: String = "general",
        name: String,
        description: String,
        timeframe: ScaleTimeframe,
        meta: ScaleMeta? = nil,
        items: [ScaleItem],
        scoring: ScaleScoring
    ) {
        self.id = id
        self.domain = domain
        self.name = name
        self.description = description
        self.timeframe = timeframe
        self.meta = meta
        self.items = items
        self.scoring = scoring
    }

    var maximumScore: Int {
        items.reduce(0) { partialResult, item in
            partialResult + (item.options.map(\.score).max() ?? 0)
        }
    }

    var minimumScore: Int {
        items.reduce(0) { partialResult, item in
            partialResult + (item.options.map(\.score).min() ?? 0)
        }
    }
}

struct ScaleTimeframe: Codable, Sendable, Equatable {
    let label: String
    let value: Int?
    let unit: String?

    init(label: String, value: Int? = nil, unit: String? = nil) {
        self.label = label
        self.value = value
        self.unit = unit
    }

    var displayLabel: String {
        label
    }

    private enum CodingKeys: String, CodingKey {
        case label
        case value
        case unit
    }

    init(from decoder: any Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let legacyLabel = try? singleValue.decode(String.self) {
            label = legacyLabel
            value = nil
            unit = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        value = try container.decodeIfPresent(Int.self, forKey: .value)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
    }
}

struct ScaleMeta: Codable, Sendable, Equatable {
    let itemsCount: Int
    let maxScore: Int
    let version: String
}

struct ScaleItemFlag: RawRepresentable, Codable, Sendable, Hashable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static let suicideRisk = ScaleItemFlag(rawValue: "suicide_risk")
}

struct ScaleItem: Codable, Sendable, Identifiable, Equatable {
    let id: Int
    let title: String
    let flags: [ScaleItemFlag]
    let options: [ScaleOption]

    init(
        id: Int,
        title: String,
        flags: [ScaleItemFlag] = [],
        options: [ScaleOption]
    ) {
        self.id = id
        self.title = title
        self.flags = flags
        self.options = options
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case flags
        case options
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        flags = try container.decodeIfPresent([ScaleItemFlag].self, forKey: .flags) ?? []
        options = try container.decode([ScaleOption].self, forKey: .options)
    }
}

enum ScaleOptionVariant: String, Codable, Sendable {
    case increase
    case decrease
}

struct ScaleOption: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let sourceID: String?
    let text: String
    let score: Int
    let variant: ScaleOptionVariant?

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case score
        case variant
    }

    init(
        id: UUID = UUID(),
        sourceID: String? = nil,
        text: String,
        score: Int,
        variant: ScaleOptionVariant? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.text = text
        self.score = score
        self.variant = variant
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let sourceID = try container.decodeIfPresent(String.self, forKey: .id) {
            self.sourceID = sourceID
            id = UUID.deterministic(from: sourceID)
        } else if let uuidID = try container.decodeIfPresent(UUID.self, forKey: .id) {
            sourceID = uuidID.uuidString
            id = uuidID
        } else {
            sourceID = nil
            id = UUID()
        }

        text = try container.decode(String.self, forKey: .text)
        score = try container.decode(Int.self, forKey: .score)
        variant = try container.decodeIfPresent(ScaleOptionVariant.self, forKey: .variant)
    }
}

struct ScaleScoring: Codable, Sendable, Equatable {
    let ranges: [ScoreRange]

    func interpretation(for score: Int) -> ScoreRange? {
        ranges.first { $0.contains(score) }
    }
}

struct ScoreRange: Codable, Sendable, Equatable {
    let min: Int
    let max: Int
    let label: String
    let severity: String
    let color: String

    func contains(_ score: Int) -> Bool {
        score >= min && score <= max
    }
}

struct ScaleAnswer: Codable, Sendable, Equatable, Hashable {
    let itemID: Int
    let selectedScore: Int
    let selectedOptionID: UUID?
    let selectedText: String?

    init(
        itemID: Int,
        selectedScore: Int,
        selectedOptionID: UUID? = nil,
        selectedText: String? = nil
    ) {
        self.itemID = itemID
        self.selectedScore = selectedScore
        self.selectedOptionID = selectedOptionID
        self.selectedText = selectedText
    }
}

struct ScaleComputedResult: Sendable, Equatable {
    let patientID: UUID
    let scaleID: String
    let date: Date
    let totalScore: Int
    let maximumScore: Int
    let severity: String
    let interpretationLabel: String
    let color: String
    let answers: [ScaleAnswer]
}

private extension UUID {
    static func deterministic(from rawValue: String) -> UUID {
        let digest = SHA256.hash(data: Data(rawValue.utf8))
        var bytes = Array(digest.prefix(16))

        // Versión 5 + variante RFC 4122 para UUID estable y estándar.
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            )
        )
    }
}
