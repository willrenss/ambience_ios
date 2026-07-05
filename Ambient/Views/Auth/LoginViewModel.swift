import Observation
import Foundation

@Observable
@MainActor
final class OnboardingViewModel {
    // Step 0: nickname, 1: age, 2: hometown, 3: interests
    var step: Int = 0

    var nickname: String = ""
    var ageText: String = ""
    var hometown: String = ""
    var searchText: String = ""
    var interests: [Interest] = []
    var selectedInterestIDs: Set<UUID> = []

    var isLoading: Bool = false
    var errorMessage: String? = nil

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var ageValue: Int? { Int(ageText) }

    // Backend stores a real birthdate; the wizard only collects age, so we
    // derive an approximate one (month/day are lost, which is fine — nothing
    // downstream depends on more than the age it produces).
    private var birthdateFromAge: Date {
        Calendar.current.date(byAdding: .year, value: -(ageValue ?? 20), to: Date()) ?? Date()
    }

    var filteredInterests: [Interest] {
        let base = searchText.trimmingCharacters(in: .whitespaces).isEmpty
            ? interests
            : interests.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        // Selected chips float to the front so they stay visible while browsing.
        return base.sorted { a, b in
            let aSel = selectedInterestIDs.contains(a.id)
            let bSel = selectedInterestIDs.contains(b.id)
            return aSel && !bSel
        }
    }

    var canContinueCurrentStep: Bool {
        switch step {
        case 0: return !nickname.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return (ageValue ?? 0) >= 13 && (ageValue ?? 0) <= 120
        case 2: return true  // hometown is optional
        default: return !selectedInterestIDs.isEmpty
        }
    }

    func loadInterests() async {
        do {
            interests = try await InterestService.shared.fetchInterests()
        } catch {
            errorMessage = "Couldn't load interests. Check your server connection."
        }
    }

    func toggle(_ interest: Interest) {
        if selectedInterestIDs.contains(interest.id) {
            selectedInterestIDs.remove(interest.id)
        } else {
            selectedInterestIDs.insert(interest.id)
        }
    }

    func goBack() {
        guard step > 0 else { return }
        errorMessage = nil
        step -= 1
    }

    // Shared by the "Continue" and "Skip" actions on the final step — Skip only
    // shortcuts past browsing/searching, it still needs >=1 interest because the
    // backend rejects signup otherwise (no-interest accounts can't happen).
    func advance() async {
        guard canContinueCurrentStep else {
            if step == 3 { errorMessage = "Pick at least one interest to continue." }
            return
        }
        errorMessage = nil
        if step < 3 {
            step += 1
        } else {
            await signUp()
        }
    }

    private func signUp() async {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let town = hometown.trimmingCharacters(in: .whitespaces)

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let profile = try await AuthService.shared.signup(
                nickname: trimmed,
                birthdate: birthdateFromAge,
                hometown: town.isEmpty ? nil : town,
                interestIDs: Array(selectedInterestIDs)
            )
            appState.currentUser = profile
        } catch {
            errorMessage = "Could not create your account. Make sure the server is running."
        }
    }
}
