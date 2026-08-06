import SwiftUI

struct StatsOverview: View {
    let stats: GameStats

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(title: "Played", value: "\(stats.totalGames)")
                StatCard(title: "Win %", value: "\(Int(stats.winRate * 100))%")
                StatCard(title: "Loss %", value: "\(Int(stats.lossRate * 100))%")
            }
            HStack(spacing: 12) {
                StatCard(title: "Streak", value: "\(stats.currentStreak)")
                StatCard(title: "Best", value: "\(stats.bestStreak)")
                StatCard(title: "Misses", value: "\(stats.losses)")
            }
            StatCard(title: "Avg guesses", value: String(format: "%.2f", stats.averageGuesses))
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        GlassSurface(cornerRadius: 18, contentPadding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline.weight(.bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct GuessDistribution: View {
    let stats: GameStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Guess Distribution")
                .font(.headline.weight(.semibold))
            let maxValue = max(1, max(stats.guessDistribution.values.max() ?? 0, stats.misses))
            ForEach(1...GameRules.maxAttempts, id: \.self) { attempt in
                let value = stats.guessDistribution[attempt] ?? 0
                DistributionRow(label: "\(attempt)", value: value, maxValue: maxValue)
            }
            DistributionRow(label: "X", value: stats.misses, maxValue: maxValue)
        }
    }
}

private struct DistributionRow: View {
    let label: String
    let value: Int
    let maxValue: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.medium))
                .frame(width: 24)
            GeometryReader { proxy in
                let fraction = CGFloat(value) / CGFloat(maxValue)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                    if value > 0 {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(ThemeColors.greenCorrect.opacity(0.85))
                            .frame(width: proxy.size.width * min(max(fraction, 0), 1))
                    }
                    Text("\(value)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(value > 0 ? .white : .secondary)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(height: 22)
        }
    }
}

struct RecentGames: View {
    let records: [GameRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Games")
                .font(.headline.weight(.semibold))
            if records.isEmpty {
                Text("Play a few rounds to populate this list.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(records) { record in
                        RecentGameRow(record: record)
                    }
                }
            }
        }
    }
}

private struct RecentGameRow: View {
    let record: GameRecord

    var body: some View {
        let statusColor = record.won ? ThemeColors.greenCorrect : Color.red
        GlassSurface(cornerRadius: 16, contentPadding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.word)
                        .font(.subheadline.weight(.semibold))
                    Text(dateLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(record.won ? "Win" : "Loss")
                        .font(.caption.weight(.bold))
                        .foregroundColor(statusColor)
                    Text(record.won ? "\(record.guessCount) guess(es)" : "Missed in \(GameRules.maxAttempts)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var dateLabel: String {
        let date = Date(timeIntervalSince1970: TimeInterval(record.playedAtEpochMillis) / 1000)
        return DateFormatter.recentGameFormatter.string(from: date)
    }
}

private extension DateFormatter {
    static let recentGameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d - h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
