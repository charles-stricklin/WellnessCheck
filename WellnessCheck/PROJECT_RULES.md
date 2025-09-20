WellnessCheck iOS Project Rules

Start Date: 9/20/2025
Current Version: v0.001a
Target Devices: iPhone (iOS 15 through iOS 26)
Primary Test Device: iPhone 16 Pro Max (iOS 26)

⸻

Architecture
	•	Use SwiftUI for all user interfaces.
	•	Use MVVM as the main architecture.
	•	Use async/await for Apple system APIs and one-time async calls.
	•	Use Combine for continuous data streams such as motion sensors, device state monitoring, or notifications.
	•	Project folder structure:
	•	App → entry point
	•	Models → data structures
	•	ViewModels → business logic and state
	•	Views → SwiftUI screens
	•	Services → background monitoring and alerts
	•	Resources → assets, colors, fonts, localization
	•	Tests → unit tests and UI tests

⸻

Style and Formatting
	•	Swift version: Match the Swift compiler bundled with the installed Xcode (currently Swift 6.x with Xcode 26).
	•	Font: San Francisco with Dynamic Type enabled.
	•	Colors:
	•	Branded colors: light blue (#d8edf7) for backgrounds, dark blue (#0e3355) for text/icons.
	•	Provide both light and dark variants in AppColors.swift so the app adapts to the user’s mode preference.
	•	Accessibility requirements:
	•	Dynamic Type scaling
	•	VoiceOver labels for all interactive elements
	•	Contrast ratio at least 4.5:1 for text
	•	Support both Light and Dark mode
	•	Follow Apple’s Human Interface Guidelines for layout and interaction.

⸻

Versioning
	•	Version format: v0.001a → v0.002a and so on.
	•	Increment the version only for meaningful changes (new feature, bug fix, updated screen), not every commit.
	•	Each file must begin with a header that includes:
	•	Filename and purpose
	•	Version number
	•	Created date and last updated date (in Central Time)
	•	Changelog with three sections: Added, Updated, and Bug Fixes

⸻

Git and Commits
	•	Repository: github.com/charles-stricklin/WellnessCheck
	•	Commit messages must use Conventional Commits format:
	•	feat: for new features
	•	fix: for bug fixes
	•	chore: for setup or maintenance
	•	docs: for documentation changes
	•	refactor: for internal restructuring without changing behavior
	•	Commits are suggested only at the end of a session when the code compiles cleanly and we are ready to move forward.

⸻

Testing
	•	Unit tests go in the WellnessCheckTests target. Cover ViewModels, Services, and core logic.
	•	UI tests go in the WellnessCheckUITests target. Start with onboarding flow first, then add alerts and other major flows later.
	•	Every SwiftUI view must have a preview example included for testing in Xcode.

⸻

Documentation
	•	Every Swift file must include the standard header with version and changelog.
	•	Use inline comments to explain why code is written a certain way.
	•	Maintain a README in the repository for developers and testers: setup steps, build instructions, folder structure, and contribution guidelines.
	•	No separate accessibility checklist — compliance will be confirmed inline with each screen.

⸻

Collaboration Rules
	•	Break tasks into small, clear steps.
	•	Always provide complete Swift files unless partial code is specifically requested.
	•	Suggest the next two or three priorities at the end of each session.
	•	Ask clarifying questions before assuming requirements.
	•	Recommend best practices and optimizations proactively.