import SwiftUI

/// About WellnessCheck: version, the medical disclaimer, and the privacy policy.
/// The policy lives in the app as well as on the web, so it's always one tap away,
/// which App Review expects of apps that use health data.
struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image("Mascot")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .accessibilityHidden(true)
                    Text("WellnessCheck").font(.title2.bold())
                    Text("Version \(version)").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("Medical Disclaimer") {
                Text(Legal.disclaimer)
            }

            Section {
                NavigationLink("Privacy Policy") { LegalTextView(title: "Privacy Policy", text: Legal.privacyPolicy) }
                Link("Terms of Use", destination: Legal.termsURL)
                LabeledContent("Open Source Licenses", value: "None")
            } footer: {
                Text("WellnessCheck uses only Apple's own frameworks, so there are no outside licenses to list.")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LegalTextView: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum Legal {
    static let disclaimer = String(localized: """
    WellnessCheck is not a medical device and does not give medical advice, diagnosis or treatment. \
    It helps you keep track of your readings, medicines and appointments. Talk with your doctor about \
    your readings and before changing how you take any medicine. In an emergency, call 911.
    """)

    /// Apple's standard license agreement, which applies to apps without their own terms.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Keep in step with PRIVACY.md at the root of the repository, which is the web copy.
    static let privacyPolicy = String(localized: """
    Last updated November 16, 2026

    WellnessCheck is made by Stricklin Development. This policy explains what happens to the information you put in the app.

    The short version: your health information stays on your devices and in your own iCloud account. We never see it, collect it, sell it or share it.

    What the app keeps
    WellnessCheck stores what you enter: readings, medicines and doses taken, appointments, doctors, your Medical ID, and the same for any family members you add. It is saved on your iPhone, protected by the encryption iOS applies to every app's data.

    iCloud
    If you're signed in to iCloud, WellnessCheck keeps a copy in your private iCloud account so it is backed up and available on your other devices. Only you can read that copy. Stricklin Development has no access to it.

    Apple Health
    With your permission, WellnessCheck saves the readings you log to Apple Health and reads readings from your devices, your date of birth, sex and height. If you connect health records (from your doctor, hospital or the VA) in the Health app and allow it, WellnessCheck reads your medicines, allergies and lab results. Family members' readings are never written to Apple Health. You can change these permissions any time in the Health app. Information from Apple Health is never used for advertising or shared with anyone.

    What we don't do
    WellnessCheck has no accounts, no ads, no analytics and no tracking. It doesn't send your information to Stricklin Development or anyone else. The app makes no connections to our servers; we don't have any.

    Sharing
    Information leaves your devices only when you choose to send it, for example a report you share with your doctor by email, message or AirDrop.

    Reminders
    Reminders are scheduled on your iPhone. They aren't sent through any server.

    Deleting your information
    Deleting the app removes its information from your iPhone. To remove the iCloud copy, go to the Settings app, tap your name, then iCloud, then Manage Storage (or Manage Account Storage), then WellnessCheck. Readings saved to Apple Health stay there until you delete them in the Health app.

    Children
    WellnessCheck is not directed at children under 13.

    Changes
    If this policy changes, the new version will appear in the app and on the web with a new date.
    """)
}
