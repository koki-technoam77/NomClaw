import SwiftUI
import UIKit

struct LatestMealAnalysisView: View {
  @ObservedObject var store: MealJournalStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Group {
      if let entry = store.entries.first {
        MealDetailView(entry: entry, store: store)
      } else {
        VStack(spacing: 12) {
          Text("No meals yet")
            .font(.system(size: 18, weight: .semibold))
          Text("Ask the assistant to log a meal to see analysis here.")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .navigationTitle("Latest Meal")
      }
    }
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button("Close") { dismiss() }
      }
      ToolbarItem(placement: .navigationBarTrailing) {
        NavigationLink("History") {
          MealHistoryView(store: store)
        }
        .disabled(store.entries.isEmpty)
      }
    }
  }
}

struct MealHistoryView: View {
  @ObservedObject var store: MealJournalStore
  @State private var query: String = ""

  var body: some View {
    let filtered = store.search(query: query)
    let grouped = groupByDay(filtered)

    Group {
      if store.entries.isEmpty {
        VStack(spacing: 10) {
          Text("No meal history")
            .font(.system(size: 18, weight: .semibold))
          Text("Log your first meal to start a streak.")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
      } else {
        List {
          ForEach(grouped, id: \.day) { section in
            Section(sectionTitle(section.day)) {
              ForEach(section.entries) { entry in
                NavigationLink {
                  MealDetailView(entry: entry, store: store)
                } label: {
                  MealHistoryRow(entry: entry, store: store)
                }
              }
            }
          }
        }
      }
    }
    .navigationTitle("Meal History")
    .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic))
  }

  private func groupByDay(_ entries: [MealJournalEntry]) -> [(day: Date, entries: [MealJournalEntry])] {
    let cal = Calendar.current
    let grouped = Dictionary(grouping: entries) { entry in
      cal.startOfDay(for: entry.createdAt)
    }
    return grouped
      .map { (day: $0.key, entries: $0.value.sorted { $0.createdAt > $1.createdAt }) }
      .sorted { $0.day > $1.day }
  }

  private func sectionTitle(_ day: Date) -> String {
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    fmt.timeStyle = .none
    return fmt.string(from: day)
  }
}

struct MealHistoryRow: View {
  let entry: MealJournalEntry
  @ObservedObject var store: MealJournalStore

  var body: some View {
    HStack(spacing: 12) {
      MealEntryThumbnail(entry: entry, store: store)
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 8))

      VStack(alignment: .leading, spacing: 4) {
        Text(entry.mealName ?? "Meal")
          .font(.system(size: 15, weight: .medium))
          .lineLimit(1)
        HStack(spacing: 8) {
          if let cals = entry.calories {
            Text("\(formatNumber(cals)) kcal")
              .font(.system(size: 13))
              .foregroundColor(.secondary)
          }
          Text(timeString(entry.createdAt))
            .font(.system(size: 13))
            .foregroundColor(.secondary)
        }
      }
      Spacer()
    }
    .padding(.vertical, 4)
  }

  private func timeString(_ date: Date) -> String {
    let fmt = DateFormatter()
    fmt.dateStyle = .none
    fmt.timeStyle = .short
    return fmt.string(from: date)
  }

  private func formatNumber(_ value: Double) -> String {
    if value.rounded() == value { return String(Int(value)) }
    return String(format: "%.1f", value)
  }
}

struct MealDetailView: View {
  let entry: MealJournalEntry
  @ObservedObject var store: MealJournalStore

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        MealEntryHeroImage(entry: entry, store: store)
          .frame(maxWidth: .infinity)
          .frame(height: 220)
          .clipShape(RoundedRectangle(cornerRadius: 14))

        VStack(alignment: .leading, spacing: 8) {
          Text(entry.mealName ?? "Meal")
            .font(.system(size: 22, weight: .semibold))

          if let summary = entry.payload.spokenSummary, !summary.isEmpty {
            Text(summary)
              .font(.system(size: 15))
              .foregroundColor(.secondary)
          }
        }

        CardView {
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text("Calories")
                .font(.system(size: 14, weight: .semibold))
              Spacer()
              Text(calorieLine(entry.payload.meal))
                .font(.system(size: 14, design: .monospaced))
            }

            if let range = entry.payload.meal?.calorieRange,
               range.low != nil || range.high != nil {
              Text("Range: \(formatOptional(range.low))–\(formatOptional(range.high)) kcal")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }

            if let conf = entry.payload.meal?.confidence {
              Text("Confidence: \(Int((conf * 100).rounded()))%")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }

            MacroSummaryRow(macros: entry.payload.meal?.macros)
            MacroBarView(macros: entry.payload.meal?.macros)
          }
          .padding(.all, 14)
        }

        if let daily = entry.payload.dailyStatus {
          CardView {
            VStack(alignment: .leading, spacing: 8) {
              Text("Today")
                .font(.system(size: 14, weight: .semibold))

              HStack {
                Text("Consumed")
                Spacer()
                Text("\(formatOptional(daily.consumedCalories)) kcal")
                  .font(.system(size: 13, design: .monospaced))
              }
              .font(.system(size: 13))
              .foregroundColor(.secondary)

              HStack {
                Text("Remaining")
                Spacer()
                Text("\(formatOptional(daily.remainingCalories)) kcal")
                  .font(.system(size: 13, design: .monospaced))
              }
              .font(.system(size: 13))
              .foregroundColor(.secondary)

              if let pace = daily.paceStatus, !pace.isEmpty {
                Text("Pace: \(paceDisplayText(pace))")
                  .font(.system(size: 13))
                  .foregroundColor(.secondary)
              }
            }
            .padding(.all, 14)
          }
        }

        if let rec = entry.payload.nextMealRecommendation,
           let title = rec.title,
           !title.isEmpty {
          CardView {
            VStack(alignment: .leading, spacing: 8) {
              Text("Next Meal Recommendation")
                .font(.system(size: 14, weight: .semibold))
              Text(title)
                .font(.system(size: 15, weight: .medium))
              if let why = rec.why, !why.isEmpty {
                Text(why)
                  .font(.system(size: 13))
                  .foregroundColor(.secondary)
              }
            }
            .padding(.all, 14)
          }
        }

        if let notes = entry.payload.notes?.flatText, !notes.isEmpty {
          CardView {
            VStack(alignment: .leading, spacing: 8) {
              Text("Notes")
                .font(.system(size: 14, weight: .semibold))
              Text(notes)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.all, 14)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
    .navigationTitle("Meal Detail")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func calorieLine(_ meal: NutritionMeal?) -> String {
    let cals = meal?.estimatedCalories
    return "\(formatOptional(cals)) kcal"
  }

  private func formatOptional(_ value: Double?) -> String {
    guard let value else { return "--" }
    if value.rounded() == value { return String(Int(value)) }
    return String(format: "%.1f", value)
  }

  private func paceDisplayText(_ pace: String) -> String {
    switch pace.lowercased() {
    case "on_track": return "On track"
    case "behind": return "Behind"
    case "ahead": return "Ahead"
    default: return pace
    }
  }
}

struct MacroSummaryRow: View {
  let macros: NutritionMacros?

  var body: some View {
    let p = macros?.proteinG
    let c = macros?.carbsG
    let f = macros?.fatG

    return HStack {
      Text("Protein \(formatOptional(p))g")
      Spacer()
      Text("Carbs \(formatOptional(c))g")
      Spacer()
      Text("Fat \(formatOptional(f))g")
    }
    .font(.system(size: 13, design: .monospaced))
    .foregroundColor(.secondary)
  }

  private func formatOptional(_ value: Double?) -> String {
    guard let value else { return "--" }
    if value.rounded() == value { return String(Int(value)) }
    return String(format: "%.1f", value)
  }
}

struct MacroBarView: View {
  let macros: NutritionMacros?

  var body: some View {
    let p = max(macros?.proteinG ?? 0, 0)
    let c = max(macros?.carbsG ?? 0, 0)
    let f = max(macros?.fatG ?? 0, 0)
    let total = max(p + c + f, 1)
    let pw = p / total
    let cw = c / total
    let fw = f / total

    return GeometryReader { geo in
      HStack(spacing: 0) {
        Color.blue.frame(width: geo.size.width * pw)
        Color.orange.frame(width: geo.size.width * cw)
        Color.pink.frame(width: geo.size.width * fw)
      }
      .frame(height: 10)
      .clipShape(RoundedRectangle(cornerRadius: 5))
    }
    .frame(height: 10)
  }
}

struct MealEntryThumbnail: View {
  let entry: MealJournalEntry
  @ObservedObject var store: MealJournalStore
  @State private var image: UIImage?

  var body: some View {
    Group {
      if let image {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)
      } else {
        Color.gray.opacity(0.2)
          .overlay {
            Image(systemName: "fork.knife")
              .foregroundColor(.secondary)
          }
      }
    }
    .task {
      guard image == nil else { return }
      if let url = store.imageFileURL(for: entry) {
        image = UIImage(contentsOfFile: url.path)
      }
    }
  }
}

struct MealEntryHeroImage: View {
  let entry: MealJournalEntry
  @ObservedObject var store: MealJournalStore
  @State private var image: UIImage?

  var body: some View {
    ZStack {
      if let image {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)
      } else {
        Color.gray.opacity(0.2)
          .overlay {
            Image(systemName: "photo")
              .foregroundColor(.secondary)
          }
      }
    }
    .task {
      guard image == nil else { return }
      if let url = store.imageFileURL(for: entry) {
        image = UIImage(contentsOfFile: url.path)
      }
    }
  }
}
