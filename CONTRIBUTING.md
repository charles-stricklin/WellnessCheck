# Contributing to WellnessCheck

First off, thank you for considering contributing to **WellnessCheck**!  
This project is intended to help people living alone by providing peace of mind to their loved ones.  
We welcome ideas, bug reports, and code contributions.

---

## 🛠 How to Contribute

1. **Fork the repo** and create your branch from `main`.
2. **Add your changes** (code, docs, or assets).
3. **Write clear commit messages** so history is easy to follow.
4. **Submit a pull request** and describe what you’ve changed.

---

## 📐 Code Style

- Use **SwiftUI best practices**.
- Keep code **commented and documented** for future developers.
- Organize files into the existing structure:
  - `Screens/` → full app screens
  - `Views/` → reusable UI components
  - `Services/` → networking, persistence, monitoring
  - `Models/` → data models
  - `Utilities/` → helper scripts

---

## ✅ Tests

- Place unit tests in `WellnessCheckTests/`.
- Place UI tests in `WellnessCheckUITests/`.

---

## 🔒 Secrets

Do **not** commit secrets or API keys.  
Use `Code/Config/Secrets.xcconfig` (ignored in GitHub).

---

## 📄 License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
