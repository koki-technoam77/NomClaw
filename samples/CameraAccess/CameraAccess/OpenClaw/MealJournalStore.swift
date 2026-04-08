import Foundation

struct MealJournalEntry: Codable, Equatable, Identifiable {
  let id: UUID
  let createdAt: Date
  let payload: NutritionPayload
  let imageFilename: String?

  let mealName: String?
  let calories: Double?
  let notesText: String?

  init(id: UUID, createdAt: Date, payload: NutritionPayload, imageFilename: String?) {
    self.id = id
    self.createdAt = createdAt
    self.payload = payload
    self.imageFilename = imageFilename

    self.mealName = payload.meal?.name
    self.calories = payload.meal?.estimatedCalories
    self.notesText = payload.notes?.flatText
  }
}

@MainActor
final class MealJournalStore: ObservableObject {
  @Published private(set) var entries: [MealJournalEntry] = []

  private let fileManager = FileManager.default
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init() {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    enc.dateEncodingStrategy = .iso8601
    encoder = enc

    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    decoder = dec

    loadFromDisk()
  }

  func addEntry(payload: NutritionPayload, imageJPEGData: Data?) {
    let id = UUID()
    let createdAt = Date()
    var filename: String?

    if let imageJPEGData {
      filename = "\(id.uuidString).jpg"
      do {
        try ensureImagesDirectoryExists()
        let url = imagesDirectoryURL().appendingPathComponent(filename!, isDirectory: false)
        try imageJPEGData.write(to: url, options: [.atomic])
      } catch {
        filename = nil
      }
    }

    let entry = MealJournalEntry(id: id, createdAt: createdAt, payload: payload, imageFilename: filename)
    entries.insert(entry, at: 0)
    saveToDisk()
  }

  func imageFileURL(for entry: MealJournalEntry) -> URL? {
    guard let name = entry.imageFilename else { return nil }
    return imagesDirectoryURL().appendingPathComponent(name, isDirectory: false)
  }

  func search(query: String) -> [MealJournalEntry] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return entries }
    let q = trimmed.lowercased()
    return entries.filter { entry in
      if let mealName = entry.mealName?.lowercased(), mealName.contains(q) { return true }
      if let notes = entry.notesText?.lowercased(), notes.contains(q) { return true }
      return false
    }
  }

  func deleteAll() {
    entries.removeAll()
    saveToDisk()
    do {
      try fileManager.removeItem(at: imagesDirectoryURL())
    } catch {
    }
  }

  private func loadFromDisk() {
    do {
      let url = entriesFileURL()
      guard fileManager.fileExists(atPath: url.path) else {
        entries = []
        return
      }
      let data = try Data(contentsOf: url)
      entries = try decoder.decode([MealJournalEntry].self, from: data).sorted { $0.createdAt > $1.createdAt }
    } catch {
      entries = []
    }
  }

  private func saveToDisk() {
    do {
      let url = entriesFileURL()
      let data = try encoder.encode(entries)
      try data.write(to: url, options: [.atomic])
    } catch {
    }
  }

  private func documentsDirectoryURL() -> URL {
    fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
  }

  private func entriesFileURL() -> URL {
    documentsDirectoryURL().appendingPathComponent("meal_journal.json", isDirectory: false)
  }

  private func imagesDirectoryURL() -> URL {
    documentsDirectoryURL().appendingPathComponent("meal_journal_images", isDirectory: true)
  }

  private func ensureImagesDirectoryExists() throws {
    let url = imagesDirectoryURL()
    if !fileManager.fileExists(atPath: url.path) {
      try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
  }
}
