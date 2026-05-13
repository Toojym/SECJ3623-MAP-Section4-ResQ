
# ⚡ SIGAP — Sistem Integrasi Gerak Awam Pantas
<div align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/VS%20Code-007ACC?style=for-the-badge&logo=visualstudiocode&logoColor=white" />
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" />
</div>

<br/>

**SIGAP** is a Flutter-based emergency response platform connecting **Citizens**, **Volunteers**, and **Officers** into a unified crisis management system. Designed for Malaysia's flood-prone regions, it provides real-time flood alerts, family safety tracking, SOS dispatch, and role-based dashboards — all backed by Firebase.

---

## ✨ Key Features

### 🏠 Citizen
- **Personalised Profile** — Full identity (name, IC, address), emergency contact, medical vulnerabilities, and household details
- **Profile Picture** — Upload from gallery, saved directly to the database
- **Amaran Banjir Popup** — Interactive active flood warning banner with alert details and a direct link to the crisis map
- **Keselamatan Keluarga** — Real-time family member safety tracking linked to Firestore
- **SOS Button** — Always-visible emergency dispatch button docked in the bottom navigation

### 🔐 Authentication
- **Role-Based Access Control (RBAC)** — Citizen / Volunteer / Officer each get their own dashboard
- **Secure Password Change** — Re-authentication required before updating passwords (Firebase security compliance)
- **Spam Protection** — 150-second countdown lock on the Forgot Password feature
- **8-Second Network Timeout** — Fails gracefully on poor connections

### 🛠️ Tech Stack
| Layer | Technology |
|---|---|
| Framework | Flutter 3 (Dart) |
| State Management | `flutter_bloc` |
| Navigation | `go_router` |
| Backend | Firebase Auth + Cloud Firestore |
| Storage | Base64 encoding (profile images saved in Firestore) |
| UI | Google Fonts, Material 3 |
| Image Picker | `image_picker` |

---

## 📁 Project Structure

> ⚠️ **Important:** The Flutter project lives inside the **`SIGAP/`** subfolder of this repository.

```
SECJ3623-MAP-Section4-ResQ/   ← Repository root (Open THIS in VS Code)
├── lib/
│   ├── blocs/            # State management (AuthBloc)
│   ├── core/             # Theme, constants, routing, validators
│   ├── models/           # Data models (Citizen, Officer, Volunteer)
│   ├── screens/          # UI screens by role (auth, citizen, officer, volunteer)
│   ├── services/         # Firebase service layer
│   └── widgets/          # Reusable widgets (SigapTextField, SigapButton, SigapAppBar)
├── android/
├── pubspec.yaml
└── ...
```

---

## 🚀 Quick Start — Download ZIP & Run (VS Code)

No Git required. Follow these steps exactly.

### Step 1 — Prerequisites

Make sure you have all of the following installed **before** opening the project:

| Tool | Minimum Version | Download |
|---|---|---|
| Flutter SDK | 3.10+ | [flutter.dev](https://docs.flutter.dev/get-started/install) |
| Dart SDK | Included with Flutter | — |
| Android Studio | Latest | [developer.android.com](https://developer.android.com/studio) |
| VS Code | Latest | [code.visualstudio.com](https://code.visualstudio.com/) |
| Java JDK | 17+ | [adoptium.net](https://adoptium.net/) |

**VS Code Extensions required** (install from `Ctrl+Shift+X`):**
- `Dart` — by Dart Code
- `Flutter` — by Dart Code

---

### Step 2 — Download & Extract

1. Click **`Code` → `Download ZIP`** on this GitHub page
2. Extract the ZIP anywhere (e.g., `C:\Projects\`)
3. You will get a folder like `SECJ3623-MAP-Section4-ResQ-main/`

---

### Step 3 — Open the Folder in VS Code

```
VS Code → File → Open Folder → select the extracted folder
```

You should see `pubspec.yaml` immediately at the root of the VS Code Explorer.

---

### Step 4 — Install Dependencies

Open the VS Code terminal (**Ctrl + `**) and run:

```bash
flutter pub get
```

---

### Step 5 — Connect a Device

**Option A — Physical Android Phone:**
1. Go to phone **Settings → About Phone** → tap **Build Number** 7 times to unlock Developer Options
2. Go to **Settings → Developer Options** → enable **USB Debugging**
3. Connect phone via USB cable
4. Run `flutter devices` in the terminal to confirm your device is detected

**Option B — Android Emulator (via Android Studio):**
1. Open Android Studio → **Device Manager** → **Create Virtual Device**
2. Pick any phone model (e.g., Pixel 6) with **API Level 30+**
3. Start the emulator, then return to VS Code

---

### Step 6 — Run the App

```bash
flutter run
```

Or press **`F5`** in VS Code to use the built-in Flutter launcher.

---

## 🔌 Shared Database — No Setup Required

This repository is **pre-configured** with the shared SIGAP Firebase project.

The files `google-services.json` and `firebase_options.dart` are already included in the repo. **You do not need to create your own Firebase project.**

Download → `flutter pub get` → `flutter run` — and you are automatically connected to the shared live database. All team members share the same accounts, profiles, and real-time data.

---

## 🧩 Reusable Widget Library

All shared UI components live in `lib/widgets/common/`:

| Widget | Description | Used In |
|---|---|---|
| `SigapTextField` | Styled input with label, validation, eye-icon toggle | Auth screens, Profile screens |
| `SigapButton` | Primary / Outlined button with loading spinner | All screens |
| `SigapAppBar` | Consistent top app bar with optional action buttons | All dashboards & profiles |
| `LoadingOverlay` | Full-screen loading indicator | Available for use |

---

## 👥 Team — SECJ3623 MAP Section 4

| Module | Responsibility |
|---|---|
| Citizen | Profile, Dashboard, Family Safety Tracking, SOS |
| Authentication | Login, Register, Role Routing, Password Reset |
| Officer | Dashboard, Incident Management |
| Volunteer | Dashboard, Assignment Tracking |

---

*Developed for SECJ3623 Mobile Application Programming — Section 4, Universiti Teknologi Malaysia.*
