import SwiftUI
import SwiftData
import Combine
import LocalAuthentication

/// The five tabs from the PRD, plus what sits over all of them: the Face ID lock,
/// the chosen appearance, and keeping reminders in step with the data.
struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Onboarding.doneKey) private var onboardingDone = false
    @AppStorage(Preferences.appearanceKey) private var appearance = Appearance.auto.rawValue
    @AppStorage(Preferences.faceIDLockKey) private var lockEnabled = false
    @State private var router = AppRouter.shared
    @State private var isUnlocked = false

    var body: some View {
        Group {
            if onboardingDone { tabs } else { OnboardingView() }
        }
        .overlay {
            if lockEnabled && !isUnlocked { LockScreen(unlock: unlock) }
        }
        .preferredColorScheme(Appearance(rawValue: appearance)?.colorScheme)
        .task {
            if lockEnabled { await unlock() }
            await Reminders.reschedule(in: context)
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            // Lock on the way out, so the app switcher's snapshot is covered too.
            case .background: isUnlocked = false
            case .active:
                People.ensureSelf(in: context)
                Task {
                    if lockEnabled && !isUnlocked { await unlock() }
                    await Reminders.reschedule(in: context)
                }
            default: break
            }
        }
        // Any saved change (a medicine, a visit, a dose checked off) can change what to remind about.
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            Task { await Reminders.reschedule(in: context) }
        }
    }

    private var tabs: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Vitals", systemImage: "heart.text.square", value: AppTab.vitals) {
                VitalsView()
            }
            Tab("Appointments", systemImage: "calendar", value: AppTab.appointments) {
                AppointmentsView()
            }
            Tab("Meds", systemImage: "pills", value: AppTab.meds) {
                MedsView()
            }
            Tab("Doctors", systemImage: "stethoscope", value: AppTab.doctors) {
                DoctorsView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
    }

    private func unlock() async {
        let context = LAContext()
        // Device-owner authentication falls back to the passcode when Face ID fails or isn't set up.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            isUnlocked = true
            return
        }
        let ok = (try? await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                    localizedReason: String(localized: "Unlock your health information"))) ?? false
        isUnlocked = ok
    }
}

private struct LockScreen: View {
    let unlock: () async -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("WellnessCheck is locked")
                .font(.title2.bold())
            Button {
                Task { await unlock() }
            } label: {
                Text("Unlock").font(.headline).frame(maxWidth: 240)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case auto, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .auto: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

#Preview {
    ContentView()
}
