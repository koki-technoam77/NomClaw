import Foundation

struct NutritionPayload: Codable, Equatable {
  let action: String
  let spokenSummary: String?
  let meal: NutritionMeal?
  let dailyStatus: NutritionDailyStatus?
  let nextMealRecommendation: NutritionNextMealRecommendation?
  let nearbyOptions: [NutritionNearbyOption]?
  let gamification: NutritionGamification?
  let notes: NutritionNotes?

  enum CodingKeys: String, CodingKey {
    case action
    case spokenSummary = "spoken_summary"
    case meal
    case dailyStatus = "daily_status"
    case nextMealRecommendation = "next_meal_recommendation"
    case nearbyOptions = "nearby_options"
    case gamification
    case notes
  }
}

struct NutritionMeal: Codable, Equatable {
  let name: String?
  let estimatedCalories: Double?
  let calorieRange: NutritionCalorieRange?
  let macros: NutritionMacros?
  let confidence: Double?

  enum CodingKeys: String, CodingKey {
    case name
    case estimatedCalories = "estimated_calories"
    case calorieRange = "calorie_range"
    case macros
    case confidence
  }
}

struct NutritionCalorieRange: Codable, Equatable {
  let low: Double?
  let high: Double?
}

struct NutritionDailyStatus: Codable, Equatable {
  let consumedCalories: Double?
  let goalCalories: Double?
  let remainingCalories: Double?
  let macroTotals: NutritionMacros?
  let paceStatus: String?

  enum CodingKeys: String, CodingKey {
    case consumedCalories = "consumed_calories"
    case goalCalories = "goal_calories"
    case remainingCalories = "remaining_calories"
    case macroTotals = "macro_totals"
    case paceStatus = "pace_status"
  }
}

struct NutritionNextMealRecommendation: Codable, Equatable {
  let title: String?
  let suggestedCalories: Double?
  let suggestedMacros: NutritionMacros?
  let why: String?

  enum CodingKeys: String, CodingKey {
    case title
    case suggestedCalories = "suggested_calories"
    case suggestedMacros = "suggested_macros"
    case why
  }
}

struct NutritionNearbyOption: Codable, Equatable, Identifiable {
  var id: String { "\(name ?? "option")-\(estimatedCalories ?? 0)" }
  let name: String?
  let why: String?
  let estimatedCalories: Double?

  enum CodingKeys: String, CodingKey {
    case name
    case why
    case estimatedCalories = "estimated_calories"
  }
}

struct NutritionGamification: Codable, Equatable {
  let xp: Double?
  let level: Double?
  let streakDays: Double?
  let characterState: String?
  let xpEarned: Double?

  enum CodingKeys: String, CodingKey {
    case xp
    case level
    case streakDays = "streak_days"
    case characterState = "character_state"
    case xpEarned = "xp_earned"
  }
}

struct NutritionMacros: Codable, Equatable {
  let proteinG: Double?
  let carbsG: Double?
  let fatG: Double?

  enum CodingKeys: String, CodingKey {
    case proteinG = "protein_g"
    case carbsG = "carbs_g"
    case fatG = "fat_g"
  }
}

enum NutritionNotes: Codable, Equatable {
  case string(String)
  case strings([String])

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let s = try? container.decode(String.self) {
      self = .string(s)
      return
    }
    if let arr = try? container.decode([String].self) {
      self = .strings(arr)
      return
    }
    throw DecodingError.typeMismatch(
      NutritionNotes.self,
      DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected string or array of strings")
    )
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let s):
      try container.encode(s)
    case .strings(let arr):
      try container.encode(arr)
    }
  }

  var flatText: String {
    switch self {
    case .string(let s):
      return s
    case .strings(let arr):
      return arr.joined(separator: "\n")
    }
  }
}

enum NutritionPayloadParser {
  static func decode(fromToolResultText text: String) -> NutritionPayload? {
    guard let data = extractJSONObjectData(from: text) else { return nil }
    let decoder = JSONDecoder()
    return try? decoder.decode(NutritionPayload.self, from: data)
  }

  private static func extractJSONObjectData(from text: String) -> Data? {
    guard let first = text.firstIndex(of: "{"),
          let last = text.lastIndex(of: "}") else {
      return nil
    }
    guard first < last else { return nil }
    let jsonSubstring = text[first...last]
    return String(jsonSubstring).data(using: .utf8)
  }
}
