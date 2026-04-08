import SwiftUI

struct GeminiStatusBar: View {
  @ObservedObject var geminiVM: GeminiSessionViewModel

  var body: some View {
    HStack(spacing: 8) {
      // Gemini connection pill
      StatusPill(color: geminiStatusColor, text: geminiStatusText)

      // OpenClaw connection pill
      StatusPill(color: openClawStatusColor, text: openClawStatusText)
    }
  }

  private var geminiStatusColor: Color {
    switch geminiVM.connectionState {
    case .ready: return .green
    case .connecting, .settingUp: return .yellow
    case .error: return .red
    case .disconnected: return .gray
    }
  }

  private var geminiStatusText: String {
    switch geminiVM.connectionState {
    case .ready: return "Gemini"
    case .connecting, .settingUp: return "Gemini..."
    case .error: return "Gemini Error"
    case .disconnected: return "Gemini Off"
    }
  }

  private var openClawStatusColor: Color {
    switch geminiVM.openClawConnectionState {
    case .connected: return .green
    case .checking: return .yellow
    case .unreachable: return .red
    case .notConfigured: return .gray
    }
  }

  private var openClawStatusText: String {
    switch geminiVM.openClawConnectionState {
    case .connected: return "OpenClaw"
    case .checking: return "OpenClaw..."
    case .unreachable: return "OpenClaw Off"
    case .notConfigured: return "No OpenClaw"
    }
  }
}

struct StatusPill: View {
  let color: Color
  let text: String

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(color)
        .frame(width: 8, height: 8)
      Text(text)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.white)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Color.black.opacity(0.6))
    .cornerRadius(16)
  }
}

struct TranscriptView: View {
  let userText: String
  let aiText: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if !userText.isEmpty {
        Text(userText)
          .font(.system(size: 14))
          .foregroundColor(.white.opacity(0.7))
      }
      if !aiText.isEmpty {
        Text(aiText)
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.white)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(Color.black.opacity(0.6))
    .cornerRadius(12)
  }
}

struct NutritionDashboardCard: View {
  @ObservedObject var geminiVM: GeminiSessionViewModel
  @ObservedObject var mealJournalStore: MealJournalStore
  let onOpen: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text("Nutrition")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.white)
        Spacer()
        Button("Latest") {
          onOpen()
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.white)
      }

      if geminiVM.latestNutritionPayload == nil && mealJournalStore.entries.isEmpty {
        Text("Ask me to log a meal to start tracking today.")
          .font(.system(size: 13))
          .foregroundColor(.white.opacity(0.8))
      } else {
        caloriesSection
        macrosSection
        nextMealSection
        gamificationSection
        footerRow
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.black.opacity(0.6))
    .cornerRadius(12)
  }

  private var caloriesSection: some View {
    let daily = geminiVM.latestDailyStatus
    let consumed = daily?.consumedCalories ?? 0
    let goal = daily?.goalCalories ?? 0
    let remaining = daily?.remainingCalories ?? max(goal - consumed, 0)
    let progress = goal > 0 ? min(max(consumed / goal, 0), 1) : 0

    return VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("Calories")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.white.opacity(0.8))
        Spacer()
        Text("\(formatNumber(consumed))/\(formatNumber(goal))")
          .font(.system(size: 12, design: .monospaced))
          .foregroundColor(.white.opacity(0.9))
      }

      ProgressView(value: progress)
        .tint(.green)

      Text("Remaining: \(formatNumber(remaining))")
        .font(.system(size: 12))
        .foregroundColor(.white.opacity(0.8))
    }
  }

  private var macrosSection: some View {
    let macros = geminiVM.latestDailyStatus?.macroTotals ?? geminiVM.latestNutritionPayload?.meal?.macros
    let protein = macros?.proteinG
    let carbs = macros?.carbsG
    let fat = macros?.fatG

    return HStack {
      Text("Macros")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.8))
      Spacer()
      Text("P \(formatNumber(protein))g  C \(formatNumber(carbs))g  F \(formatNumber(fat))g")
        .font(.system(size: 12, design: .monospaced))
        .foregroundColor(.white.opacity(0.9))
        .lineLimit(1)
    }
  }

  @ViewBuilder
  private var nextMealSection: some View {
    if let rec = geminiVM.latestNextMealRecommendation,
       let title = rec.title,
       !title.isEmpty {
      VStack(alignment: .leading, spacing: 4) {
        Text("Next meal")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.white.opacity(0.8))
        Text(title)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.white)
          .lineLimit(2)
      }
    }
  }

  @ViewBuilder
  private var gamificationSection: some View {
    if let g = geminiVM.latestGamification {
      let xp = g.xp
      let level = g.level
      let streak = g.streakDays
      let state = g.characterState

      HStack {
        Text("XP \(formatNumber(xp))  Lvl \(formatNumber(level))  Streak \(formatNumber(streak))")
          .font(.system(size: 12, design: .monospaced))
          .foregroundColor(.white.opacity(0.9))
          .lineLimit(1)
        Spacer()
        if let state, !state.isEmpty {
          Text(state)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
            .lineLimit(1)
        }
      }
    }
  }

  private var footerRow: some View {
    let pace = geminiVM.latestDailyStatus?.paceStatus
    return HStack {
      if let pace, !pace.isEmpty {
        Text(paceDisplayText(pace))
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.white.opacity(0.75))
      }
      Spacer()
      if !mealJournalStore.entries.isEmpty {
        Text("\(mealJournalStore.entries.count) meals")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.white.opacity(0.75))
      }
    }
  }

  private func formatNumber(_ value: Double?) -> String {
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

struct ToolCallStatusView: View {
  let status: ToolCallStatus

  var body: some View {
    if status != .idle {
      HStack(spacing: 8) {
        statusIcon
        Text(status.displayText)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.white)
          .lineLimit(1)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(statusBackground)
      .cornerRadius(16)
    }
  }

  @ViewBuilder
  private var statusIcon: some View {
    switch status {
    case .executing:
      ProgressView()
        .scaleEffect(0.7)
        .tint(.white)
    case .completed:
      Image(systemName: "checkmark.circle.fill")
        .foregroundColor(.green)
        .font(.system(size: 14))
    case .failed:
      Image(systemName: "exclamationmark.circle.fill")
        .foregroundColor(.red)
        .font(.system(size: 14))
    case .cancelled:
      Image(systemName: "xmark.circle.fill")
        .foregroundColor(.yellow)
        .font(.system(size: 14))
    case .idle:
      EmptyView()
    }
  }

  private var statusBackground: Color {
    switch status {
    case .executing: return Color.black.opacity(0.7)
    case .completed: return Color.black.opacity(0.6)
    case .failed: return Color.red.opacity(0.3)
    case .cancelled: return Color.black.opacity(0.6)
    case .idle: return Color.clear
    }
  }
}

struct SpeakingIndicator: View {
  @State private var animating = false

  var body: some View {
    HStack(spacing: 3) {
      ForEach(0..<4, id: \.self) { index in
        RoundedRectangle(cornerRadius: 1.5)
          .fill(Color.white)
          .frame(width: 3, height: animating ? CGFloat.random(in: 8...20) : 6)
          .animation(
            .easeInOut(duration: 0.3)
              .repeatForever(autoreverses: true)
              .delay(Double(index) * 0.1),
            value: animating
          )
      }
    }
    .onAppear { animating = true }
    .onDisappear { animating = false }
  }
}
