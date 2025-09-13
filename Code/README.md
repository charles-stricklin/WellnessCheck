# WellnessCheck

**WellnessCheck** is an iOS app designed to provide peace of mind for people living alone and their loved ones.  
The app passively monitors device activity and can alert trusted contacts if unusual inactivity is detected.

---

## 🚀 Features (Planned & In Progress)
- **Onboarding Flow** – guide new users through setup  
- **Splash Screen** – branded entry point  
- **In-Operation Screen** – shows app is monitoring in the background  
- **Preferences Screen** – configure settings like inactivity threshold  
- **Contacts Screen** – add family or caregivers to receive alerts  
- **Emergency Alerts** – notify contacts via SMS/email (future integration with Twilio/Firebase)  

---

## 🗂 Project Structure
```
Code/WellnessCheck        # Main SwiftUI app  
Code/WellnessCheck.xcodeproj  
Code/Config/Secrets.xcconfig (ignored in GitHub)  
Design/                   # Local-only design files (not in GitHub)  
```

- `Screens/` → full-page SwiftUI screens (e.g., Onboarding, Splash)  
- `Views/` → reusable SwiftUI components (currently placeholder)  
- `Services/` → networking, persistence, background tasks (currently placeholder)  
- `Models/` → app data models  
- `Utilities/` → helper scripts (`gitpush.sh`, `gitpull.sh`)  

---

## 🔧 Requirements
- Xcode 15 or newer  
- iOS 15+ target  
- SwiftUI  

---

## 🔒 Secrets & Config
Sensitive files (e.g. API keys, service configs) live in:  
```
Code/Config/Secrets.xcconfig
```
This file is **excluded from GitHub**. Add your own local copy with the required keys if contributing.  

---

## 🧪 Tests
- `WellnessCheckTests` → unit tests  
- `WellnessCheckUITests` → UI and launch tests  

---

## 📌 Roadmap
- [ ] Implement onboarding flow  
- [ ] Add Preferences screen  
- [ ] Build out Contacts screen  
- [ ] Integrate alerting service (Twilio/Firebase)  
- [ ] Add reusable components in `Views/`  

---

## 📄 License
TBD – likely open-source with donation/shareware model.  
