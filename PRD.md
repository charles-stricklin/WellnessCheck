# Product Requirements Document (PRD): WellnessCheck iOS Personal Health Tracking App

**Product Name:** WellnessCheck  
**Platform:** iOS (Native Swift / SwiftUI Aesthetic)  
**Design System:** Obsidian Clinical (Dark Mode • Charcoal `#10131a` • Clinical Teal `#00d2b4` • SF Pro Typography)  
**Organization:** Stricklin Development, LLC  
**Regulatory Status:** Personal health record-keeping app. Not a medical device; does not diagnose, treat or monitor any condition.  

---

## 1. Executive Summary & Vision

**WellnessCheck** is a clinical-style, dark-mode personal health tracking application designed for patients managing chronic conditions, tracking critical biometrics, and collaborating directly with care teams and physicians. 

By marrying high-contrast dark clinical aesthetics with standard iOS inset-grouped interface conventions, WellnessCheck delivers calm, legible, and trustworthy vital tracking, medication adherence, appointment scheduling, and shareable doctor reports, with Apple Health as the bridge to devices and medical records.

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
| **Tab 1** | **Snapshot** | `heart.text.square` | Daily vital summary, latest readings, vital cards. |
| **Tab 2** | **Appointments** | `calendar` | Chronological doctor visits, check-ups, location routing, prep notes. |
| **Tab 3** | **Meds** | `pills` | Medication schedule (Morning, Noon, Evening, Bedtime), inventory alerts, split-pill badges. |
| **Tab 4** | **Doctors** | `stethoscope` | Care team directory, primary care physicians, specialists, instant contact. |
| **Tab 5** | **Settings** | `gearshape` | Medical profile, emergency contacts, Apple Health connection, biometric security, notifications. |

---

## 4. Screen-by-Screen Specifications

### 4.1. Welcome & Onboarding
- **Emblem & Branding:** Glowing ECG pulse badge with `#00d2b4` ambient glow.
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

### 4.3. Vitals Log & Snapshot
- **Persistent Header:** User profile avatar, and "WellnessCheck" brand wordmark.
- **Biometric Tiles:** High-contrast tiles for Heart Rate (BPM), Blood Pressure (mmHg), SpO2 (%), Blood Glucose (mg/dL), Body Temperature.
- **Out-of-Range Flags:** Status pills (In Range, Out of Range) measured against target ranges the user or their doctor sets, in clinical teal and amber.
- **Actions:** Quick filter pills and manual reading logging modal entry.

### 4.4. Medication Management
- **Schedule Groups:** Time-based bucketing (Morning, Afternoon, Evening, Bedtime).
- **Clinical Badges:** Dosage strength indicators, visual pill-split icons, glowing schedule status tags.
- **Inventory Tracking:** Low-supply reminders telling the user it is time to call the pharmacy.

### 4.5. Appointments Management
- **Chronological Timeline:** Upcoming, completed, and canceled clinical visits.
- **Card Metadata:** Provider name, clinic location, specialty badge, calendar synchronization.
- **Action Triggers:** Add new visit floating action button (FAB) or navigation header action.

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
- **Security & Preferences:** Face ID / Biometrics toggle, Passcode / PIN fallback, Measurement Reminders, Appearance & Accessibility options.
- **Units:** Blood glucose in mg/dL and temperature in °F by default; each can be switched in Settings (mmol/L, °C). Readings are stored in one standard unit and converted for display, so switching never alters past data.

### 4.8. About & System Architecture
- **Navigation:** Frosted-glass navigation bar with `< Settings` back trigger and `Done` action.
- **App Info:** Version and build number, read from the app bundle.
- **Compliance & Legal:** Links for Terms of Service, Privacy Policy, and Open Source Licenses.
- **Medical Disclaimer:** Plain statement that WellnessCheck is not a medical device, does not provide medical advice, and that readings should be discussed with a physician.

---

## 5. Design System Tokens: Obsidian Clinical

- **Theme Mode:** Dark Mode Only.
- **Palette:**
  - `Background / Surface Dim`: `#10131a`
  - `Surface Container Low`: `#191c22`
  - `Surface Container`: `#20242c`
  - `Surface Container High / Bright`: `#2a2f3a` / `#363941`
  - `Primary / Accent`: `#00d2b4` (Clinical Teal)
  - `Text On Surface`: `#e1e3ec` (Crisp Off-White)
  - `Text On Surface Variant`: `#8992a2` (Muted Secondary)
  - `Outline / Dividers`: `rgba(255, 255, 255, 0.08)` to `0.15`
- **Typography:** SF Pro (the iOS system font, with Dynamic Type) using monospaced digits for biometric numerals.
- **Geometry & Elevation:** iOS Inset-Grouped cards, 16-pt continuous corner radius, flat elevation with subtle glow highlights.

---

## 6. Technical Requirements & Non-Functionals

1. **Security & Privacy:**
   - Client-side biometric encryption (AES-256 for local SQLite / CoreData cache).
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
- Units default to mg/dL and °F, switchable to mmol/L and °C.

**Later, if ever**
- Sending readings or alerts directly to a doctor's office.
- Automated pharmacy reorders.
- Direct connections to the VA or other medical record systems.
- Direct Bluetooth connections to devices.

**Dropped**
- "Verified" doctors.
