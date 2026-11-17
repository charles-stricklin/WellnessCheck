import SwiftUI
import SwiftData
import UserNotifications

/// First-launch setup: a brief splash (logo, name, version), welcome, Apple Health permission, the owner's name, units and preferences,
/// the owner's date of birth, sex and height, and optional family members. Everything chosen here can be changed later, so
/// every step after Welcome can be skipped without consequence.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.createdAt) private var people: [Person]

    @AppStorage(Onboarding.doneKey) private var isDone = false
    @AppStorage(Onboarding.healthSkippedKey) private var healthSkipped = false
    @AppStorage(Units.glucoseMmolKey) private var glucoseMmol = false
    @AppStorage(Units.celsiusKey) private var celsius = false
    @AppStorage(Units.kilogramsKey) private var kilograms = false
    @AppStorage(Preferences.openToLogReadingKey) private var openToLogReading = true
    @AppStorage(Preferences.formVitalsKey) private var formVitals = Preferences.defaultFormVitals

    @State private var step: Step = .splash
    /// Flips the slide direction so Back feels like going back.
    @State private var isGoingBack = false
    @State private var name = ""
    @State private var isAddingPerson = false
    @State private var birthDate: Date?
    @State private var sex: Sex?
    /// Whole inches, or whole centimeters when `kilograms` (metric) is on.
    @State private var height: Int?
    @State private var filledFromHealth = false
    @FocusState private var nameFocused: Bool

    private enum Step: Int, CaseIterable {
        // About comes after Units so height shows in the units they just picked.
        case splash, welcome, health, name, units, vitals, about, family, reminders
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .splash: splash
                case .welcome: welcome
                case .health: healthPrimer
                case .name: nameStep
                case .units: unitsStep
                case .vitals: vitalsStep
                case .about: aboutStep
                case .family: familyStep
                case .reminders: remindersStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: isGoingBack ? .leading : .trailing),
                                    removal: .move(edge: isGoingBack ? .trailing : .leading)).combined(with: .opacity))
        }
        .overlay(alignment: .topLeading) {
            // Nothing to go back to from the splash or Welcome.
            if step.rawValue > Step.welcome.rawValue {
                Button("Back", systemImage: "chevron.left", action: goBack)
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }
        .animation(.easeInOut, value: step)
        .sheet(isPresented: $isAddingPerson) { AddPersonView() }
    }

    // MARK: Steps

    private static let splashSeconds = 2.0

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// Logo, name and version, then on to Welcome by itself; a tap moves on sooner.
    private var splash: some View {
        VStack(spacing: 16) {
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(height: 220)
                .accessibilityHidden(true)
            Text("WellnessCheck")
                .font(.largeTitle.bold())
            Text("Version \(appVersion)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StepLayout<EmptyView>.paper)
        .environment(\.colorScheme, .light)
        .contentShape(.rect)
        .onTapGesture { leaveSplash() }
        .task {
            try? await Task.sleep(for: .seconds(Self.splashSeconds))
            leaveSplash()
        }
    }

    private var welcome: some View {
        StepLayout(
            mascot: "Mascot",
            title: "Welcome to WellnessCheck",
            message: "Keep your vital signs, medicines and doctor visits organized in one place, backed up to your own iCloud, with reports you can share with your doctor.",
            footer: "Your health information stays on your iPhone and in your own iCloud account, protected by Apple's encryption. We never see it."
        ) {
            primaryButton("Get Started") { advance(from: .welcome) }
        }
    }

    private var healthPrimer: some View {
        StepLayout(
            mascot: "Mascot",
            partnerIcon: "AppleHealthIcon",
            title: "Connect Apple Health",
            message: "WellnessCheck can save the readings you log to Apple Health, and show readings from your blood pressure cuff, scale, glucose meter and other devices.",
            footer: "Next, Apple will ask which items to share. You can change this any time in the Health app."
        ) {
            primaryButton("Allow Access") {
                Task {
                    healthSkipped = false
                    await HealthStore.shared.requestAccess()
                    advance(from: .health)
                }
            }
            skipButton {
                healthSkipped = true
                advance(from: .health)
            }
        }
    }

    private var nameStep: some View {
        StepLayout(
            symbol: "person.crop.circle.fill",
            title: "What's your name?",
            message: "It's shown on your profile and on the reports you share with your doctor."
        ) {
            TextField("Your name", text: $name)
                .textContentType(.name)
                .font(.title3)
                .padding()
                .background(.fill.tertiary, in: .rect(cornerRadius: 12))
                .focused($nameFocused)
                .submitLabel(.next)
                .onSubmit(saveNameAndAdvance)
                .padding(.bottom, 8)
            primaryButton("Continue", action: saveNameAndAdvance)
                .disabled(trimmedName.isEmpty)
            skipButton { advance(from: .name) }
        }
        .onAppear {
            if name.isEmpty, let me = owner, me.name != People.defaultOwnerName { name = me.name }
            nameFocused = true
        }
    }

    private var unitsStep: some View {
        StepLayout(
            symbol: "slider.horizontal.3",
            title: "Your preferences",
            message: "Pick the units you're used to seeing, and where the app opens. You can change these later in Settings."
        ) {
            VStack(spacing: 16) {
                UnitPicker(label: "Blood sugar", isOn: $glucoseMmol, off: "mg/dL", on: "mmol/L")
                UnitPicker(label: "Temperature", isOn: $celsius, off: "°F", on: "°C")
                UnitPicker(label: "Weight and height", isOn: $kilograms, off: "lb", on: "kg")
                OpenToLogReadingToggle(isOn: $openToLogReading)
                    .padding(.top, 4)
            }
            .padding(.bottom, 8)
            primaryButton("Continue") { advance(from: .units) }
        }
    }

    private var vitalsStep: some View {
        StepLayout(
            symbol: "checklist",
            title: "What do you measure?",
            message: "Check the readings you take regularly. Each gets a box on your reading form. You can add others any time."
        ) {
            VStack(spacing: 0) {
                FormVitalsChecklist(stored: $formVitals)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(.fill.tertiary, in: .rect(cornerRadius: 12))
            .padding(.bottom, 8)
            primaryButton("Continue") { advance(from: .vitals) }
        }
    }

    private var aboutStep: some View {
        StepLayout(
            symbol: "person.text.rectangle.fill",
            title: "About you",
            message: "Your date of birth, sex and height help make sense of your readings, and appear on the reports you share with your doctor.",
            footer: filledFromHealth ? "Filled in from Apple Health. Change anything that isn't right." : nil
        ) {
            VStack(spacing: 0) {
                LabeledContent("Date of birth") {
                    if let birthDate {
                        DatePicker("Date of birth", selection: Binding { birthDate } set: { self.birthDate = $0 },
                                   in: ...Date.now, displayedComponents: .date)
                            .labelsHidden()
                    } else {
                        Button("Choose") { birthDate = Self.suggestedBirthDate }
                    }
                }
                .padding(.vertical, 10)
                Divider()
                LabeledContent("Sex") {
                    Picker("Sex", selection: $sex) {
                        Text("Choose").tag(Sex?.none)
                        ForEach(Sex.allCases) { Text($0.label).tag(Sex?.some($0)) }
                    }
                    .labelsHidden()
                }
                .padding(.vertical, 4)
                Divider()
                LabeledContent("Height") {
                    Picker("Height", selection: $height) {
                        Text("Choose").tag(Int?.none)
                        ForEach(heightRange, id: \.self) { Text(heightLabel($0)).tag(Int?.some($0)) }
                    }
                    .labelsHidden()
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal)
            .background(.fill.tertiary, in: .rect(cornerRadius: 12))
            .padding(.bottom, 8)
            primaryButton("Continue", action: saveAboutAndAdvance)
                .disabled(birthDate == nil || sex == nil || height == nil)
        }
        .task { await prefillAbout() }
    }

    private var familyStep: some View {
        StepLayout(
            symbol: "person.2.fill",
            title: "Keeping track for family?",
            message: "Add anyone whose readings you look after, such as a spouse or parent. Their readings stay in WellnessCheck and aren't added to your Apple Health.",
            footer: "You can add family members later from the Vitals tab."
        ) {
            let family = people.filter { !$0.isSelf }
            if !family.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(family) { person in
                        Label(person.relationship.isEmpty ? person.name : "\(person.name) (\(person.relationship))",
                              systemImage: "person.fill")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.fill.tertiary, in: .rect(cornerRadius: 12))
            }
            Button("Add Family Member", systemImage: "person.badge.plus") { isAddingPerson = true }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            primaryButton(family.isEmpty ? "Not Now" : "Continue") { advance(from: .family) }
        }
    }

    private var remindersStep: some View {
        StepLayout(
            symbol: "bell.badge.fill",
            title: "Want reminders?",
            message: "WellnessCheck can remind you when it's time for your medicines, your readings and your appointments.",
            footer: "Next, your iPhone will ask to allow notifications. You can change reminders any time in Settings."
        ) {
            primaryButton("Turn On Reminders") {
                Task {
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                    finish()
                }
            }
            skipButton { finish() }
        }
    }

    // MARK: Pieces

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func skipButton(action: @escaping () -> Void) -> some View {
        Button("Skip", action: action)
            .frame(maxWidth: .infinity)
    }

    // MARK: About you

    /// Where the date picker opens when there's nothing to start from; the app's
    /// audience is mostly older adults, so mid-century saves a lot of scrolling.
    private static var suggestedBirthDate: Date {
        Calendar.current.date(from: DateComponents(year: 1955, month: 1, day: 1)) ?? .now
    }

    private static let cmPerInch = 2.54

    private var heightRange: ClosedRange<Int> { kilograms ? 100...230 : 39...90 }

    private func heightLabel(_ value: Int) -> String {
        kilograms ? "\(value) cm" : "\(value / 12)′ \(value % 12)″"
    }

    private func heightValue(fromCm cm: Double) -> Int {
        Int((kilograms ? cm : cm / Self.cmPerInch).rounded())
    }

    /// Starts from what's already saved (they came back to this step), otherwise
    /// from Apple Health. Never overwrites something they've already chosen here.
    private func prefillAbout() async {
        if let me = owner {
            if birthDate == nil { birthDate = me.birthDate }
            if sex == nil { sex = me.sex }
            if height == nil, let cm = me.heightCm { height = heightValue(fromCm: cm) }
        }
        guard !healthSkipped, birthDate == nil || sex == nil || height == nil else { return }
        let health = await HealthStore.shared.profile()
        var filled = false
        if birthDate == nil, let date = health.birthDate { birthDate = date; filled = true }
        if sex == nil, let value = health.sex { sex = value; filled = true }
        if height == nil, let cm = health.heightCm { height = heightValue(fromCm: cm); filled = true }
        filledFromHealth = filled
    }

    private func saveAboutAndAdvance() {
        guard let birthDate, let sex, let height else { return }
        let me = People.ensureSelf(in: context)
        me.birthDate = birthDate
        me.sex = sex
        me.heightCm = kilograms ? Double(height) : Double(height) * Self.cmPerInch
        advance(from: .about)
    }

    // MARK: Flow

    private var owner: Person? { people.first { $0.isSelf } }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Moves on only if still on `current`. Apple's Health sheet takes a moment to
    /// appear, and a second tap in that gap used to skip a whole step.
    private func advance(from current: Step) {
        guard step == current else { return }
        guard let next = Step(rawValue: step.rawValue + 1) else { return finish() }
        nameFocused = false
        isGoingBack = false
        step = next
    }

    /// Guards against the timer and a tap both firing.
    private func leaveSplash() {
        advance(from: .splash)
    }

    private func saveNameAndAdvance() {
        guard !trimmedName.isEmpty else { return }
        People.ensureSelf(in: context).name = trimmedName
        advance(from: .name)
    }

    /// Whatever was saved on the earlier step is shown again there, so going back loses nothing.
    private func goBack() {
        guard step.rawValue > Step.welcome.rawValue, let previous = Step(rawValue: step.rawValue - 1) else { return }
        nameFocused = false
        isGoingBack = true
        step = previous
    }

    private func finish() {
        try? context.save()
        isDone = true
    }
}

/// Shared shape of every setup screen: picture and words up top, actions at the bottom.
private struct StepLayout<Actions: View>: View {
    var symbol: String? = nil
    /// Artwork from the asset catalog. Alone it fills the header; alongside `partnerIcon`
    /// it sits to the left on a white tile, so the pairing reads as
    /// "this app ↔ Apple Health" rather than two loose images.
    var mascot: String? = nil
    /// Another app's official icon (asset catalog), shown to the right of the mascot.
    /// Apple's Health artwork must be used unaltered, so it's drawn as-is.
    var partnerIcon: String? = nil
    let title: String
    let message: String
    var footer: String? = nil
    @ViewBuilder let actions: Actions

    /// Warm off-white page color; the mascot's tile stays pure white so it stands out.
    static var paper: Color { Color(red: 0.98, green: 0.97, blue: 0.94) }

    /// Screens that feature the mascot sit on the off-white "paper". Those screens
    /// stay in light appearance even in Dark Mode, because dark-mode text would be
    /// unreadable on a light background.
    private var onPaper: Bool { mascot != nil }

    var body: some View {
        content
            .background(onPaper ? Self.paper : Color.clear)
            .environment(\.colorScheme, onPaper ? .light : colorScheme)
    }

    @Environment(\.colorScheme) private var colorScheme

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Group {
                        if let mascot, let partnerIcon {
                            HStack(spacing: 16) {
                                Image(mascot)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(10)
                                    .frame(width: 88, height: 88)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(.white)
                                    )
                                // Two-way arrows: readings flow both to and from Health.
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.title.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Image(partnerIcon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 88, height: 88)
                            }
                            // Our icon always sits left of the partner's, even in
                            // right-to-left languages where iOS would mirror the row.
                            .environment(\.layoutDirection, .leftToRight)
                        } else if let mascot {
                            Image(mascot)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 260)
                        } else if let symbol {
                            Image(systemName: symbol)
                                .font(.system(size: 88))
                                .foregroundStyle(.tint)
                        }
                    }
                    .padding(.top, 32)
                    .accessibilityHidden(true)
                    Text(title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 12) {
                actions
                if let footer {
                    Text(footer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

enum Onboarding {
    static let doneKey = "onboarding.done"
    /// Set when the person tapped Skip on the Health screen, so the app doesn't
    /// pop Apple's permission sheet on them anyway when they reach the Vitals tab.
    static let healthSkippedKey = "onboarding.healthSkipped"
}

#Preview {
    OnboardingView()
        .modelContainer(for: [Person.self, Reading.self], inMemory: true)
}
