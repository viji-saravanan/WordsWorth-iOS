import SwiftUI

struct AppRootView: View {
    private let services: AppServices
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var gameViewModel: GameViewModel
    @StateObject private var dashboardViewModel: DashboardViewModel
    @AppStorage("wordgame_prefers_dark") private var prefersDark = false

    init(services: AppServices = .shared) {
        self.services = services
        _authViewModel = StateObject(wrappedValue: AuthViewModel())
        _gameViewModel = StateObject(
            wrappedValue: GameViewModel(
                wordService: services.wordService,
                statsRepository: services.statsRepository
            )
        )
        _dashboardViewModel = StateObject(
            wrappedValue: DashboardViewModel(
                wordService: services.wordService,
                dailyWordsService: services.dailyWordsService
            )
        )
    }

    var body: some View {
        Group {
            if authViewModel.state.user == nil {
                AuthView(viewModel: authViewModel)
            } else {
                DashboardView(
                    authViewModel: authViewModel,
                    dashboardViewModel: dashboardViewModel,
                    gameViewModel: gameViewModel,
                    prefersDark: $prefersDark
                )
            }
        }
        .preferredColorScheme(prefersDark ? .dark : .light)
        .environment(\.legibilityWeight, .regular)
        .dynamicTypeSize(.medium)
    }
}
