# Product Requirements Document (PRD): WellnessCheck iOS Clinical Telemetry App

**Product Name:** WellnessCheck  
**Platform:** iOS (Native Swift / SwiftUI Aesthetic)  
**Design System:** Obsidian Clinical (Dark Mode • Charcoal `#10131a` • Clinical Teal `#00d2b4` • Inter Typography)  
**Organization:** Stricklin Development, LLC  
**Regulatory Status:** Personal health record-keeping app. Not a medical device; does not diagnose, treat or monitor any condition.  

---

## 1. Executive Summary & Vision

**WellnessCheck** is a clinical-style, dark-mode personal health tracking application designed for patients managing chronic conditions, tracking critical biometrics, and collaborating directly with care teams and physicians. 

By marrying high-contrast dark clinical aesthetics with standard iOS inset-grouped interface conventions, WellnessCheck delivers calm, legible, and trustworthy vital tracking, medication adherence, appointment scheduling, and VA/EHR health record synchronization.

---

## 2. Core Personas & User Needs

1. **Chronic Condition Patient (e.g., Hypertension, Diabetes, Cardiac Care)**
   - *Needs:* Rapid visual feedback on current biometrics (heart rate, BP, SpO2, blood glucose), automated trend alerts, clear medication split-dose reminders.
2. **Caregiver / Family Manager**
   - *Needs:* Profile switching between self and family dependents, emergency contact accessibility, exportable doctor reports.
3. **Clinical / Provider Coordination**
   - *Needs:* Direct physician directory, automated clinical summary exports, verifiable telemetry synchronization with electronic health records (Apple Health, VA Health, EHR systems).

---

## 3. Product Architecture & Navigation

The core application follows an iOS standard 5-tab docked bottom navigation bar with frosted translucent glass blur (`backdrop-blur-md`) and safe-area affordances:

| Tab | Label | Primary Icon | Purpose |
| :--- | :--- | :--- | :--- |
| **Tab 1** | **Snapshot** | `ecg_heart` / `monitor_heart` | Daily vital summary, real-time biometrics, critical telemetry cards. |
| **Tab 2** | **Appointments** | `calendar_today` | Chronological doctor visits, check-ups, location routing, prep notes. |
| **Tab 3** | **Meds** | `medication` | Medication schedule (Morning, Noon, Evening, Bedtime), inventory alerts, split-pill badges. |
| **Tab 4** | **Doctors** | `person_search` | Care team directory, primary care physicians, specialists, instant contact. |
| **Tab 5** | **Settings** | `settings` | Medical profile, emergency contacts, VA/EHR integrations, biometric security, notifications. |

---

## 4. Screen-by-Screen Specifications

### 4.1. Welcome & Onboarding
- **Emblem & Branding:** Glowing ECG pulse badge with `#00d2b4` ambient glow.
- **Value Proposition:** Accurate, organized tracking, secure cloud sync, real-time doctor alerts.
- **Primary CTA:** "Get Started" navigating seamlessly into health setup.
- **Security Footer:** End-to-end encryption and a plain-language privacy commitment.

### 4.2. Health Data Permission Request (Pre-Prompt Primer)
- **Role:** Trust-building pre-permission screen before triggering iOS HealthKit / biometric system prompts.
- **Components:**
  - Status header with dismiss (`close`) and `Skip` actions.
  - Centered glowing squircle telemetry icon with pulse waveform and status node.
  - Value cards detailing Real-Time Telemetry, Doctor & Clinic Coordination, and Early Anomaly Alerts.
  - Primary button: `Allow Access` with secondary `Customize Data Sharing`.
  - Privacy footnote confirming granular permission controls in Settings.

### 4.3. Vitals Log & Snapshot
- **Persistent Header:** Top iOS status bar (`9:41`, signal, Wi-Fi, battery), user profile avatar, and "WellnessCheck" brand wordmark.
- **Biometric Tiles:** High-contrast tiles for Heart Rate (BPM), Blood Pressure (mmHg), SpO2 (%), Blood Glucose (mg/dL), Body Temperature.
- **Anomaly Detection:** Visual status pills (Normal, Elevated, Review Needed) with clinical teal and amber alerts.
- **Actions:** Quick filter pills and manual reading logging modal entry.

### 4.4. Medication Management
- **Schedule Groups:** Time-based bucketing (Morning, Afternoon, Evening, Bedtime).
- **Clinical Badges:** Dosage strength indicators, visual pill-split icons, glowing schedule status tags.
- **Inventory Tracking:** Low-supply threshold warnings with automated pharmacy reorder triggers.

### 4.5. Appointments Management
- **Chronological Timeline:** Upcoming, completed, and canceled clinical visits.
- **Card Metadata:** Provider name, clinic location, specialty badge, calendar synchronization.
- **Action Triggers:** Add new visit floating action button (FAB) or navigation header action.

### 4.6. Doctor Management
- **Care Team Roster:** Inset list of verified practitioners with profile headshots, specialty tags, phone/email actions, and hospital affiliations.
- **Header Profile Bar:** Persistent user profile chip with frosted backdrop.

### 4.7. Settings & Medical Profile
- **Profile & Family Switcher:** Top avatar dropdown supporting multi-profile family health management.
- **Medical Identification:**
  - Blood Type (e.g., `O Positive (O+)`).
  - Date of Birth with age calculation (e.g., `May 5, 1960 (66 yrs)`).
  - Allergies list (e.g., `Cedar`) rendered in clean body styling.
  - Emergency Contact designation (e.g., `Jenny Fultz`).
- **External Integrations:** VA Account Connection (OAuth2 / FHIR credentials), Apple Health sync.
- **Security & Preferences:** Face ID / Biometrics toggle, Passcode / PIN fallback, Measurement Reminders, Appearance & Accessibility options.

### 4.8. About & System Architecture
- **Navigation:** Frosted-glass navigation bar with `< Settings` back trigger and `Done` action.
- **Telemetry Info:** Build versioning (`2.4.1 (Build 890)`), Telemetry Core (`v3.2`), and encrypted relay node ID.
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
- **Typography:** Inter (Standard Apple SF Pro alternative) with strict tabular figures for biometric numerals.
- **Geometry & Elevation:** iOS Inset-Grouped cards, `rounded-2xl` surfaces, flat elevation with subtle glow highlights.

---

## 6. Technical Requirements & Non-Functionals

1. **Security & Privacy:**
   - Client-side biometric encryption (AES-256 for local SQLite / CoreData cache).
   - Zero telemetry transmission without explicit user authentication.
   - Granular HealthKit sharing opt-in and revocation.
2. **Performance:**
   - 60 FPS scrolling across long vitals history and appointment timelines.
   - Low-latency Bluetooth LE connection with peripheral biometric sensors.
3. **Accessibility:**
   - Dynamic Type support with high-contrast accessibility toggles.
   - Full VoiceOver labels on all telemetry icons, pulse graphs, and state toggles.
