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

## 🔌 Setup Your Own Backend (API Configuration)

If you are cloning this repository to build your own version, you must connect it to your own Firebase project (which serves as the backend API for SIGAP).

1. Go to the [Firebase Console](https://console.firebase.google.com/) and create a new project.
2. Enable **Authentication** (Email/Password provider).
3. Enable **Firestore Database** and set the security rules to allow authenticated reads and writes:
   ```text
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```
4. Install the FlutterFire CLI on your computer:
   ```bash
   dart pub global activate flutterfire_cli
   ```
5. Run the configuration tool inside the SIGAP project folder to generate your own API keys:
   ```bash
   flutterfire configure
   ```
   *(This will automatically update `lib/firebase_options.dart` and the native config files with your own project's API keys).*

---
*Developed for SECJ3623 MAP Section 4.*
