import SwiftUI
import UIKit

struct DashboardView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var dashboardViewModel: DashboardViewModel
    @ObservedObject var gameViewModel: GameViewModel
    @Binding var prefersDark: Bool

    @State private var toastMessage: String?
    @State private var showToast = false

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            dashboardTabs

            VStack {
                HStack {
                    Spacer()
                    SettingsMenu(prefersDark: $prefersDark, onSignOut: authViewModel.signOut)
                }
                Spacer()
            }
            .padding(.top, 10)
            .padding(.trailing, 16)

            if showToast, let toastMessage {
                VStack {
                    Spacer()
                    GlassToast(message: toastMessage)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 16)
                }
            }
        }
        .onChange(of: gameViewModel.state.userMessage) { message in
            guard let message else { return }
            toastMessage = message
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showToast = true
            }
            gameViewModel.consumeUserMessage()
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showToast = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var dashboardTabs: some View {
        if #available(iOS 18.0, *) {
            tabView
                .tabViewStyle(.sidebarAdaptable)
        } else {
            tabView
                .tabViewStyle(.automatic)
        }
    }

    private var tabView: some View {
        TabView(selection: selectionBinding) {
            ForEach(DashboardTab.allCases) { tab in
                DashboardPage(
                    tab: tab,
                    dashboardState: dashboardViewModel.state,
                    gameState: gameViewModel.state,
                    onDictionaryQueryChange: dashboardViewModel.updateDictionaryQuery,
                    onDictionarySearch: dashboardViewModel.searchDictionary,
                    onThesaurusQueryChange: dashboardViewModel.updateThesaurusQuery,
                    onThesaurusSearch: dashboardViewModel.searchThesaurus,
                    onRefreshDailyWords: { dashboardViewModel.refreshDailyWords(force: true) },
                    onLetter: gameViewModel.onLetterInput,
                    onDelete: gameViewModel.onBackspace,
                    onSubmit: gameViewModel.onSubmitGuess,
                    onModeSelect: gameViewModel.onModeSelected,
                    onNewGame: gameViewModel.onNewGameRequested,
                    onRefreshStats: { gameViewModel.refreshStats() }
                )
                .tag(tab)
                .tabItem {
                    Label(tab.label, systemImage: tab.iconName)
                }
            }
        }
        .simultaneousGesture(swipeGesture)
    }

    private var selectionBinding: Binding<DashboardTab> {
        Binding(
            get: { dashboardViewModel.state.selectedTab },
            set: { dashboardViewModel.selectTab($0) }
        )
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > 60, abs(vertical) < 40 else { return }
                let tabs = DashboardTab.allCases
                guard let index = tabs.firstIndex(of: dashboardViewModel.state.selectedTab) else { return }
                let nextIndex = horizontal < 0 ? min(index + 1, tabs.count - 1) : max(index - 1, 0)
                guard nextIndex != index else { return }
                dashboardViewModel.selectTab(tabs[nextIndex])
            }
    }
}

private struct SettingsMenu: View {
    @Binding var prefersDark: Bool
    let onSignOut: () -> Void

    var body: some View {
        Menu {
            Toggle(isOn: $prefersDark) {
                Label("Dark theme", systemImage: "moon.fill")
            }
            Button(role: .destructive, action: onSignOut) {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            GlassSurface(cornerRadius: 18, contentPadding: EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
    }
}

private struct DashboardPage: View {
    let tab: DashboardTab
    let dashboardState: DashboardUiState
    let gameState: GameUiState
    let onDictionaryQueryChange: (String) -> Void
    let onDictionarySearch: () -> Void
    let onThesaurusQueryChange: (String) -> Void
    let onThesaurusSearch: () -> Void
    let onRefreshDailyWords: () -> Void
    let onLetter: (Character) -> Void
    let onDelete: () -> Void
    let onSubmit: () -> Void
    let onModeSelect: (WordLengthOption) -> Void
    let onNewGame: () -> Void
    let onRefreshStats: () -> Void

    var body: some View {
        if tab == .play {
            VStack(spacing: 16) {
                paneContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 16)
            .padding(.top, 24)
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    paneContent
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }
        }
    }

    @ViewBuilder
    private var paneContent: some View {
        switch tab {
        case .dictionary:
            DictionaryPane(
                state: dashboardState,
                onQueryChange: onDictionaryQueryChange,
                onSearch: onDictionarySearch
            )
        case .daily:
            DailyWordsPane(
                state: dashboardState,
                onRefresh: onRefreshDailyWords
            )
        case .play:
            PlayPane(
                state: gameState,
                onLetter: onLetter,
                onDelete: onDelete,
                onSubmit: onSubmit,
                onModeSelect: onModeSelect,
                onNewGame: onNewGame
            )
        case .thesaurus:
            ThesaurusPane(
                state: dashboardState,
                onQueryChange: onThesaurusQueryChange,
                onSearch: onThesaurusSearch
            )
        case .stats:
            StatsPane(
                state: gameState,
                onRefreshStats: onRefreshStats
            )
        }
    }
}

private struct DictionaryPane: View {
    let state: DashboardUiState
    let onQueryChange: (String) -> Void
    let onSearch: () -> Void

    var body: some View {
        GlassSurface(cornerRadius: 28) {
            VStack(spacing: 12) {
                PaneHeader(title: "Dictionary", systemImage: "magnifyingglass")
                GlassTextField(placeholder: "Search a word", text: Binding(
                    get: { state.dictionaryQuery },
                    set: onQueryChange
                ))
                GlassButton(
                    title: "Search",
                    systemImage: "arrow.right.circle.fill",
                    background: [Color(red: 0.55, green: 0.86, blue: 1.0), Color(red: 0.38, green: 0.76, blue: 0.98)],
                    action: onSearch
                )
                if state.isDictionaryLoading {
                    LoadingRow(message: "Fetching definition...")
                } else if let error = state.dictionaryError {
                    ErrorRow(message: error)
                } else if let insight = state.dictionaryResult {
                    WordInsightCard(insight: insight)
                } else {
                    HintRow(message: "Search to see meaning, family, usage, and synonyms.")
                }
            }
        }
    }
}

private struct DailyWordsPane: View {
    let state: DashboardUiState
    let onRefresh: () -> Void

    var body: some View {
        GlassSurface(cornerRadius: 28) {
            VStack(spacing: 12) {
                PaneHeader(title: "Words of the Day", systemImage: "book.fill") {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                if state.isDailyLoading {
                    LoadingRow(message: "Curating today's words...")
                } else if let error = state.dailyError {
                    ErrorRow(message: error)
                } else if state.dailyWords.isEmpty {
                    HintRow(message: "No words yet. Tap refresh.")
                } else {
                    VStack(spacing: 12) {
                        ForEach(state.dailyWords) { insight in
                            WordInsightCard(insight: insight, compact: true)
                        }
                    }
                }
            }
        }
    }
}

private struct PlayPane: View {
    let state: GameUiState
    let onLetter: (Character) -> Void
    let onDelete: () -> Void
    let onSubmit: () -> Void
    let onModeSelect: (WordLengthOption) -> Void
    let onNewGame: () -> Void

    var body: some View {
        GlassSurface(cornerRadius: 32) {
            VStack(spacing: 12) {
                PaneHeader(title: "Play", systemImage: "play.circle.fill")
                WordGamePlayView(
                    state: state,
                    onLetter: onLetter,
                    onDelete: onDelete,
                    onSubmit: onSubmit,
                    onModeSelect: onModeSelect,
                    onNewGame: onNewGame
                )
            }
        }
    }
}

private struct ThesaurusPane: View {
    let state: DashboardUiState
    let onQueryChange: (String) -> Void
    let onSearch: () -> Void

    var body: some View {
        GlassSurface(cornerRadius: 28) {
            VStack(spacing: 12) {
                PaneHeader(title: "Thesaurus", systemImage: "text.book.closed")
                GlassTextField(placeholder: "Explore synonyms", text: Binding(
                    get: { state.thesaurusQuery },
                    set: onQueryChange
                ))
                GlassButton(
                    title: "Find synonyms",
                    systemImage: "sparkles",
                    background: [Color(red: 0.55, green: 0.95, blue: 0.86), Color(red: 0.37, green: 0.86, blue: 0.76)],
                    action: onSearch
                )
                if state.isThesaurusLoading {
                    LoadingRow(message: "Finding alternatives...")
                } else if let error = state.thesaurusError {
                    ErrorRow(message: error)
                } else if let result = state.thesaurusResult {
                    ThesaurusResultCard(result: result)
                } else {
                    HintRow(message: "Search to see a curated synonym list.")
                }
            }
        }
    }
}

private struct StatsPane: View {
    let state: GameUiState
    let onRefreshStats: () -> Void

    var body: some View {
        GlassSurface(cornerRadius: 28) {
            VStack(spacing: 12) {
                PaneHeader(title: "Statistics", systemImage: "chart.bar") {
                    Button(action: onRefreshStats) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                    }
                }
                GlassChip(text: state.isCloudEnabled ? "Synced in the cloud" : "Stored locally on this device")
                if state.statsState.isLoading {
                    LoadingRow(message: "Syncing stats...")
                } else if let stats = state.statsState.stats {
                    StatsOverview(stats: stats)
                    GuessDistribution(stats: stats)
                    RecentGames(records: stats.recentGames)
                } else {
                    HintRow(message: state.statsState.error ?? "Play a round to generate stats.")
                }
            }
        }
    }
}

private struct PaneHeader<Action: View>: View {
    let title: String
    let systemImage: String
    let action: Action

    init(title: String, systemImage: String) where Action == EmptyView {
        self.title = title
        self.systemImage = systemImage
        self.action = EmptyView()
    }

    init(title: String, systemImage: String, @ViewBuilder action: () -> Action) {
        self.title = title
        self.systemImage = systemImage
        self.action = action()
    }

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
            Spacer()
            action
        }
    }
}

private struct WordInsightCard: View {
    let insight: WordInsight
    var compact: Bool = false

    var body: some View {
        GlassSurface(cornerRadius: 22, contentPadding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)) {
            VStack(spacing: 8) {
                Text(insight.word.capitalized)
                    .font(.headline.weight(.bold))
                if insight.meanings.isEmpty {
                    Text("Definition not available yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(displayedMeanings.indices, id: \.self) { index in
                        MeaningSection(
                            meaning: displayedMeanings[index],
                            compact: compact,
                            showAntonyms: !compact
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var displayedMeanings: [WordMeaning] {
        compact ? Array(insight.meanings.prefix(1)) : insight.meanings
    }
}

private struct ThesaurusResultCard: View {
    let result: ThesaurusResult

    var body: some View {
        GlassSurface(cornerRadius: 22, contentPadding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)) {
            VStack(spacing: 8) {
                Text(result.word.capitalized)
                    .font(.headline.weight(.bold))
                if result.meanings.isEmpty {
                    Text("No definitions available for this word.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(result.meanings.indices, id: \.self) { index in
                        MeaningSection(
                            meaning: result.meanings[index],
                            compact: false,
                            showAntonyms: true
                        )
                    }
                }
                if !result.fallbackSynonyms.isEmpty {
                    WordListFlow(title: "General synonyms", words: result.fallbackSynonyms, compact: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MeaningSection: View {
    let meaning: WordMeaning
    let compact: Bool
    let showAntonyms: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let part = meaning.partOfSpeech, !part.isEmpty {
                Text(part.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            let definitions = compact ? Array(meaning.definitions.prefix(1)) : meaning.definitions
            ForEach(definitions.indices, id: \.self) { index in
                DefinitionBlock(
                    index: index + 1,
                    definition: definitions[index],
                    compact: compact,
                    showAntonyms: showAntonyms
                )
            }
        }
    }
}

private struct DefinitionBlock: View {
    let index: Int
    let definition: WordDefinition
    let compact: Bool
    let showAntonyms: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(index). \(definition.definition)")
                .font(.subheadline)
            if let example = definition.example, !example.isEmpty {
                Text("Example: \(example)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if !definition.synonyms.isEmpty {
                WordListFlow(title: "Synonyms", words: definition.synonyms, compact: compact)
            }
            if showAntonyms, !definition.antonyms.isEmpty {
                WordListFlow(title: "Antonyms", words: definition.antonyms, compact: compact)
            }
        }
    }
}

private struct WordListFlow: View {
    let title: String
    let words: [String]
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
            FlowLayout(words: Array(words.prefix(compact ? 6 : 10))) { word in
                GlassChip(text: word)
            }
        }
    }
}

private struct LoadingRow: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private struct ErrorRow: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.red)
    }
}

private struct HintRow: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
}

private struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let words: Data
    let content: (Data.Element) -> Content

    init(words: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.words = words
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let rows = buildRows(for: width)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(rows.indices, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(rows[row], id: \.self) { word in
                            content(word)
                        }
                    }
                }
            }
            .frame(height: estimatedHeight(for: rows.count))
        }
        .frame(height: 110)
    }

    private func textWidth(_ word: Data.Element) -> CGFloat {
        let text = String(describing: word)
        let size = text.size(withAttributes: [.font: UIFont.systemFont(ofSize: 12, weight: .medium)])
        return size.width + 28
    }

    private func buildRows(for width: CGFloat) -> [[Data.Element]] {
        var rows: [[Data.Element]] = [[]]
        var currentWidth: CGFloat = 0
        for word in words {
            let wordWidth = textWidth(word)
            if currentWidth + wordWidth > width, !rows.last!.isEmpty {
                rows.append([word])
                currentWidth = wordWidth
            } else {
                rows[rows.count - 1].append(word)
                currentWidth += wordWidth
            }
        }
        return rows
    }

    private func estimatedHeight(for rows: Int) -> CGFloat {
        let rowHeight: CGFloat = 28
        let spacing: CGFloat = 6
        return CGFloat(rows) * rowHeight + CGFloat(max(rows - 1, 0)) * spacing
    }
}
