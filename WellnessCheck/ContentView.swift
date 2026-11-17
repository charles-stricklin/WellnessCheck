import SwiftUI

/// The five tabs from the PRD. Placeholders stand in until each screen is built.
struct ContentView: View {
    @AppStorage(Onboarding.doneKey) private var onboardingDone = false

    var body: some View {
        if onboardingDone { tabs } else { OnboardingView() }
    }

    private var tabs: some View {
        TabView {
            Tab("Vitals", systemImage: "heart.text.square") {
                VitalsView()
            }
            Tab("Appointments", systemImage: "calendar") {
                placeholder("Appointments")
            }
            Tab("Meds", systemImage: "pills") {
                placeholder("Meds")
            }
            Tab("Doctors", systemImage: "stethoscope") {
                placeholder("Doctors")
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }

    private func placeholder(_ title: String) -> some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: "hammer", description: Text("Coming soon."))
                .navigationTitle(title)
        }
    }
}

#Preview {
    ContentView()
}
