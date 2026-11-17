import SwiftUI

/// The five tabs from the PRD.
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
                AppointmentsView()
            }
            Tab("Meds", systemImage: "pills") {
                MedsView()
            }
            Tab("Doctors", systemImage: "stethoscope") {
                DoctorsView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
}
