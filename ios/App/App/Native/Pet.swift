import Foundation

/// One row of the live `pets` table. The field names and types mirror
/// exactly what the web app writes today (verified against the v4.3
/// web app's insert row on 2026-11-10) — nothing here is invented:
/// `weight` is free text on the web ("12 lbs", "3.9 kg"), `birthday`
/// is a date string, and everything but id/name/species can be empty.
struct Pet: Codable, Identifiable, Equatable {
    let id: String
    let ownerId: String?
    let name: String
    let species: String // "dog" or "cat" in the web app today
    let breed: String?
    let birthday: String?
    let weight: String?
    let vetClinic: String?
    let vetName: String?
    let vetPhone: String?
    let food: String?
    let allergies: String?
    let notes: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case species
        case breed
        case birthday
        case weight
        case vetClinic = "vet_clinic"
        case vetName = "vet_name"
        case vetPhone = "vet_phone"
        case food
        case allergies
        case notes
        case updatedAt = "updated_at"
    }

    var speciesLabel: String { species == "cat" ? "Cat" : "Dog" }
    var speciesEmoji: String { species == "cat" ? "🐱" : "🐶" }

    /// One-line summary for the list row: "Cat · Siamese · 3.9 kg",
    /// built only from fields that actually have values.
    var subtitle: String {
        var parts = [speciesLabel]
        if let breed, !breed.isEmpty { parts.append(breed) }
        if let weight, !weight.isEmpty { parts.append(weight) }
        return parts.joined(separator: " · ")
    }
}
