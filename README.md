# ⚡ SIGAP (Sistem Integrasi Gerak Awam Pantas)

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
</div>

<br/>

**SIGAP** is a cutting-edge, high-performance Flutter application designed for rapid civilian response and integration. Built with a highly modular architecture, SIGAP connects everyday citizens, volunteers, and officers into a unified ecosystem.

## ✨ Cinematic User Experience
We believe utility software should be beautiful. SIGAP features a premium **Glassmorphism UI** and **Cinematic Page Routing**:
- **Hero Flight Animations:** The SIGAP lightning bolt physically flies and morphs across the screen as you navigate between authentication phases.
- **Buttery Fade Transitions:** No harsh page snapping. Every form melts gracefully into the next using custom `FadeTransition` logic.
- **Smart Form Interactions:** Input fields use a modern, borderless 16px radius design that organically lights up upon interaction.

## 🚀 Key Features

### 🔐 Bulletproof Authentication
- **Role-Based Access Control (RBAC):** Dedicated dashboards and secure routing for `Citizen`, `Volunteer`, and `Officer` roles.
- **Intelligent Validation:** Real-time form checks, secure regex validations, and polite, inline error handling (e.g., immediate feedback for existing emails without breaking the UI flow).
- **Spam Protection:** An integrated 150-second live countdown timer locks the "Forgot Password" functionality to prevent server spam.
- **Fail-safe Network Handling:** 8-second global timeouts prevent infinite loading screens on poor connections, failing gracefully and safely.

## 🛠️ Tech Stack & Architecture

- **Framework:** Flutter (Dart)
- **State Management:** BLoC (Business Logic Component) via `flutter_bloc`
- **Routing:** `go_router` for deep-linking and state-driven navigation protection.
- **Backend:** Firebase Authentication & Cloud Firestore
- **Architecture:** Feature-based Clean Architecture (Blocs, Screens, Services, Models)

## 📁 Folder Structure
```text
lib/
├── blocs/        # State management (AuthBloc, etc.)
├── core/         # Theming, Constants, Routing, and Utilities
├── models/       # Data serialization (Citizen, Officer, Volunteer)
├── screens/      # UI Views categorized by feature/role
├── services/     # Firebase interaction layer
└── widgets/      # Reusable, customized UI components
```

## ⚙️ Quick Start (Running Locally)

1. **Clone the repository**
   ```bash
   git clone https://github.com/cheng-jiayi/SECJ3623-MAP-Section4-ResQ.git
   cd SIGAP
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the App**
   ```bash
   flutter run
   ```

## 🔌 Shared Database Configuration

This repository is already pre-configured to connect to the central **SIGAP Firebase Project**. 

Because the API configuration files (`google-services.json` and `firebase_options.dart`) are included directly in this repository, **you do not need to set up your own database**. 

Any team member who clones this project and runs `flutter run` will instantly be connected to the exact same shared live database. All user accounts, profiles, and data will automatically sync across everyone's devices out-of-the-box!

---
*Developed for SECJ3623 MAP Section 4.*
