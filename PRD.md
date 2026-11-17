# Product Requirements Document (PRD): WellnessCheck iOS Personal Health Tracking App

**Product Name:** WellnessCheck  
**Platform:** iPhone (Native Swift / SwiftUI). iPad and Apple Watch planned for later versions.  
**Design System:** Obsidian Clinical (Light / Dark / Auto • Charcoal `#10131a` • Clinical Teal `#00d2b4` • SF Pro Typography)  
**Organization:** Stricklin Development, LLC  
**Regulatory Status:** Personal health record-keeping app. Not a medical device; does not diagnose, treat or monitor any condition.  

---

## 1. Executive Summary & Vision

**WellnessCheck** is a clinical-style personal health tracking application designed for patients managing chronic conditions, tracking critical biometrics, and collaborating directly with care teams and physicians. 

By marrying high-contrast clinical aesthetics with standard iOS inset-grouped interface conventions, WellnessCheck delivers calm, legible, and trustworthy vital tracking, medication adherence, appointment scheduling, and shareable doctor reports, with Apple Health as the bridge to devices and medical records.

---

## 2. Core Personas & User Needs

1. **Chronic Condition Patient (e.g., Hypertension, Diabetes, Cardiac Care)**
   - *Needs:* Rapid visual feedback on current biometrics (heart rate, BP, SpO2, blood glucose), trend views and out-of-range flags, clear medication split-dose reminders.
2. **Caregiver / Family Manager**
   - *Needs:* Profile switching between self and family dependents, emergency contact accessibility, exportable doctor reports.
3. **Clinical / Provider Coordination**
   - *Needs:* Direct physician directory, shareable PDF summaries, and access to medical records through Apple Health (including VA records).

---

## 3. Product Architecture & Navigation

The core application follows an iOS standard 5-tab docked tab bar using the system translucent material:

| Tab | Label | Primary Icon | Purpose |
| :--- | :--- | :--- | :--- |
| **Tab 1** | **Vitals** | `heart.text.square` | Daily vital summary, latest readings, vital cards. |
| **Tab 2** | **Appointments** | `calendar` | Chronological doctor visits, check-ups, location routing, prep notes. |
| **Tab 3** | **Meds** | `pills` | Medication schedule (Morning, Noon, Evening, Bedtime), inventory alerts, split-pill badges. |
| **Tab 4** | **Doctors** | `stethoscope` | Care team directory, primary care physicians, specialists, instant contact. |
| **Tab 5** | **Settings** | `gearshape` | Medical profile, emergency contacts, Apple Health connection, biometric security, notifications. |

---

## 4. Screen-by-Screen Specifications

### 4.1. Welcome & Onboarding
- **Emblem & Branding:** The heart mascot on a warm off-white page. First launch opens with a brief splash (mascot, name, version), then Welcome.
- **Setup Steps:** Apple Health, name, units and where the app opens, which vitals to track, date of birth / sex / height, family members, and reminders. Every step has Back.
- **Later Launches:** Open straight to the reading form (switchable in Settings), and again after an hour or more in the background.
- **Value Proposition:** Accurate, organized tracking, iCloud backup, and reports to share with your doctor.
- **Primary CTA:** "Get Started" navigating seamlessly into health setup.
- **Security Footer:** End-to-end encryption and a plain-language privacy commitment.

### 4.2. Health Data Permission Request (Pre-Prompt Primer)
- **Role:** Trust-building pre-permission screen before triggering iOS HealthKit / biometric system prompts.
- **Components:**
  - Status header with dismiss (`close`) and `Skip` actions.
  - Centered glowing squircle health icon with pulse waveform and status node.
  - Value cards detailing Organized Readings, Doctor & Clinic Coordination, and Out-of-Range Flags.
  - Primary button: `Allow Access` with secondary `Customize Data Sharing`.
  - Privacy footnote confirming granular permission controls in Settings.

### 4.3. Vitals
- **Persistent Header:** User profile avatar, and "WellnessCheck" brand wordmark.
- **Biometric Tiles:** High-contrast tiles for Heart Rate (BPM), Blood Pressure (mmHg), SpO2 (%), Blood Glucose (mg/dL), Body Temperature, Weight.
- **Out-of-Range Flags:** Status pills (In Range, Out of Range) measured against target ranges the user or their doctor sets, in clinical teal and amber.
- **Reading Form:** One row per vital the user checked in setup or Settings, filled in together and saved with one tap; empty boxes save nothing; any other vital can be added for one time. Medicines due now appear as one collapsible checklist line on the same form.
- **Lab Results:** From Health Records, latest per test with flags and normal range.
- **Report:** PDF for the doctor (2 weeks, 30 or 90 days), shared through the iOS share sheet.

### 4.4. Medication Management
- **Schedules:** Each medicine has its own times, each with its own amount (halves allowed), and a frequency: every day, every other day, certain days, or as needed. Not fixed Morning/Bedtime buckets.
- **Taken Checklist:** On the reading form, medicines due now (about 4 hours before to 3 hours after their time) in one compact drop-down; check what you took, unchecked isn't recorded. As-needed medicines are logged from the Meds tab.
- **Status:** Taking, Paused or Stopped, with a reason; schedule and status changes are kept as a dated history.
- **Add from Health Records:** Medicines from any connected provider, chosen from a checklist.
- **Out of Scope:** Supplies (sensors, needles, strips, CPAP parts) are not tracked.
- **Clinical Badges:** Dosage strength indicators, visual pill-split icons, glowing schedule status tags.
- **Inventory Tracking:** Low-supply reminders telling the user it is time to call the pharmacy.
- **Medication Detail:** Optional photo of the pill (so it can be recognized at a glance), shape, color and imprint; generic name; what it is for; prescribing doctor (linked to the Doctors tab); refills remaining; dosage strength with a note when the tablet is scored for splitting; special instructions (e.g., take with food, avoid grapefruit).
- **Log Dose:** One-tap "Log Dose Taken" button, showing when the last dose was logged.

### 4.5. Appointments Management
- **Chronological Timeline:** Upcoming, completed, and canceled clinical visits.
- **Card Metadata:** Provider name, clinic location, specialty badge, calendar synchronization.
- **Action Triggers:** Add new visit floating action button (FAB) or navigation header action.
- **Visit Card Actions:** Add to Calendar, Directions (opens Apple Maps), per-visit reminder (e.g., 2 hours before), and prep notes (e.g., fasting instructions, what to bring, questions to ask).

### 4.6. Doctor Management
- **Care Team Roster:** Inset list of the user's own practitioners, entered by the user, with optional photos, specialty tags, phone/email actions, and hospital affiliations.
- **Header Profile Bar:** Persistent user profile chip with frosted backdrop.

### 4.7. Settings & Medical Profile
- **Profile & Family Switcher:** Top avatar dropdown supporting multi-profile family health management.
- **Medical Identification:**
  - Blood Type (e.g., `O Positive (O+)`).
  - Date of Birth with age calculation (e.g., `March 3, 1955 (71 yrs)`).
  - Allergies list (e.g., `Penicillin`, `Pollen`) rendered in clean body styling.
  - Emergency Contact designation (name, relationship, phone).
- **External Integrations:** Apple Health connection (readings from devices such as blood pressure cuffs, plus Health Records including VA), iCloud backup.
- **Security & Preferences:** Face ID / Biometrics toggle, Passcode / PIN fallback, Measurement Reminders (e.g., morning glucose and blood pressure, evening blood pressure, a prompt two hours after meals), Appearance (Light / Dark / Auto) & Accessibility options.
- **Units:** Blood glucose in mg/dL, temperature in °F and weight in lb by default; each can be switched in Settings (mmol/L, °C, kg). Readings are stored in one standard unit and converted for display, so switching never alters past data.

### 4.8. About & System Architecture
- **Navigation:** Frosted-glass navigation bar with `< Settings` back trigger and `Done` action.
- **App Info:** Version and build number, read from the app bundle.
- **Compliance & Legal:** Links for Terms of Service, Privacy Policy, and Open Source Licenses.
- **Medical Disclaimer:** Plain statement that WellnessCheck is not a medical device, does not provide medical advice, and that readings should be discussed with a physician.

---

## 5. Design System Tokens

- **Theme Mode:** Light, Dark, or Auto (follows the iPhone's setting), chosen in Settings. Screens use iOS's system backgrounds and text colors in both modes.
- **Palette:**
  - `Primary / Accent`: `#DB392A` (Heart Red), matching the mascot and app icon.
  - `Paper`: warm off-white behind mascot screens (setup), which stay light even in Dark Mode.
  - `In Range`: teal; `Out of Range`, low supply and dose changes: amber.
- **Typography:** SF Pro (the iOS system font, with Dynamic Type) using monospaced digits for biometric numerals.
- **Geometry & Elevation:** iOS Inset-Grouped cards, 16-pt continuous corner radius, flat elevation with subtle glow highlights.

---

## 6. Technical Requirements & Non-Functionals

1. **Security & Privacy:**
   - Data stored on the iPhone is protected by the encryption iOS applies to every app's files, locked whenever the phone is locked; iCloud copies are encrypted by Apple.
   - Zero data transmission without explicit user authentication.
   - Granular HealthKit sharing opt-in and revocation.
2. **Performance:**
   - 60 FPS scrolling across long vitals history and appointment timelines.
3. **Accessibility:**
   - Dynamic Type support with high-contrast accessibility toggles.
   - Full VoiceOver labels on all vital icons, pulse graphs, and state toggles.

---

## 7. Version 1 Scope

WellnessCheck version 1 runs entirely on the user's devices. It needs no server run by Stricklin Development and no agreement with any outside organization. Apple Health does the heavy lifting.

**In version 1**
- iCloud backup and sync across the user's own devices (Apple-run, free).
- Shareable doctor report: a PDF the user can email, print or AirDrop.
- Low-supply medication reminders (the user calls the pharmacy).
- Readings from blood pressure cuffs, scales, glucose meters and other devices, read from Apple Health rather than connected directly.
- Medical records, including VA records, read from Apple Health's Health Records.
- A doctor list the user types in themselves.
- Weight tracking alongside the other vitals.
- Units default to mg/dL, °F and lb, switchable to mmol/L, °C and kg.
- Family profiles: keep readings for yourself and for family members on one phone, and switch between them. Only your own readings go to and come from Apple Health - Apple Health belongs to the phone's owner, so a family member's readings stay inside WellnessCheck.
- iPhone only. iPads can run the iPhone app as-is.

**Later, if ever**
- Apple Watch app (version 2): check off meds and log quick readings from the wrist.
- Native iPad layout.
- Sending readings or alerts directly to a doctor's office.
- Automated pharmacy reorders.
- Direct connections to the VA or other medical record systems.
- Direct Bluetooth connections to devices.

**Dropped**
- "Verified" doctors.
