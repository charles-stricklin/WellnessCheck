import SwiftUI

/// The five tabs from the PRD. Each is a placeholder until its screen is built.
struct ContentView: View {
    var body: some View {
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
                placeholder("Settings")
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
