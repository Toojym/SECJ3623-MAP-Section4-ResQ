# SIGAP — Sistem Integrasi Gerak Awam Pantas
### Fast when it matters most.

---

## 📌 Executive Summary
**SIGAP** (meaning "fast" in Malay) is a Flutter-based mobile crisis response platform designed to bridge the gap between **Citizens, Volunteers, and Government Agencies** during disasters in Malaysia. By unifying real-time data and communication, SIGAP ensures that every second counts.

### The Problem
Malaysia faces recurring disasters (floods, landslides, haze) where:
* **Citizens** feel lost and unable to signal for help.
* **Volunteers** lack coordination, leading to duplicated efforts.
* **Government Agencies** receive fragmented and delayed information.
* **Aid & Donations** suffer from slow paperwork and lack of transparency.

### The Solution
A unified platform powered by **AWANIS**, an AI assistant that provides role-aware, bilingual (Bahasa Malaysia + English) guidance to all users.

---

## 🤖 Meet AWANIS
**Automated Welfare & Alert Navigation Intelligence System**
AWANIS is the "calm, knowledgeable presence" within the app. Powered by the **Anthropic Claude API**, she provides:

* **For Citizens:** Step-by-step survival guidance, SOS filing assistance, and relief claim explanations.
* **For Volunteers:** Task summaries, incident briefings, and post-mission debriefing.
* **For Officers:** Natural language queries of Firestore data (e.g., "How many SOS in Gombak?"), drafting situation reports, and resource reallocation suggestions.

---

## 👥 User Roles & Features

### 🏠 1. The Citizen
* **SOS Broadcasting:** One-tap SOS with live location and incident type (Flood, Fire, Medical, etc.).
* **Safety Status:** Mark yourself as "Safe," "Evacuated," or "Need Help" for family and responders.
* **Aid & Claims:** Submit and track relief aid claims (IC, household size, damage evidence) in real-time.
* **Transparent Donations:** Donate via FPX/Credit Card and see exactly how funds are spent (food packs, medical supplies, etc.).
* **Offline Support:** Access cached emergency checklists and first aid guides via Flutter Hive.

### 🤝 2. The Volunteer
* **Active/Inactive Toggle:** A simple switch to control visibility to dispatchers.
* **Grab-style Dispatch:** Receive mission notifications with urgency scores; accept/decline with one tap.
* **Task Checklist:** Log supplies delivered and people assisted directly in the field.
* **SIGAP Mata:** Earn points for missions, redeemable for certificates endorsed by **NADMA** or **Bomba**.

### 🏛️ 3. The Government Officer
* **Command & Control:** Live heatmap of SOS clusters and volunteer movements.
* **Geofencing:** Declare disaster zones and trigger mass push alerts to citizens in the area.
* **Resource Management:** Track inventory (tents, boats, food) and receive low-stock alerts.
* **Bulk Claims:** Approve relief claims in bulk for declared disaster zones.

---

## 🛠️ Technical Stack
| Layer | Technology |
| :--- | :--- |
| **Frontend** | Flutter (MVVM + Bloc Pattern) |
| **Auth & DB** | Firebase Auth + Firestore |
| **Storage** | Firebase Storage |
| **AI Chat** | Claude API via Firebase Cloud Functions |
| **Maps** | Google Maps Flutter Plugin |
| **Payments** | Stripe / iPay88 (FPX Support) |
| **Offline** | Flutter Hive (Cache) |

---

## 📅 Roadmap (Sprint Breakdown)
1.  **Sprint 1:** Authentication & Role-based UI personalization.
2.  **Sprint 2:** Core Crisis CRUD (SOS submission, Live Map, Safety Updates).
3.  **Sprint 3:** Claims processing, Donation campaigns, and Volunteer dispatch.
4.  **Sprint 4:** AWANIS AI integration, FAQ module, and Points system.

---

## 💰 Business Model
* **SaaS:** Licensing for NADMA, Civil Defence, and Local Councils (RM 50k-200k/year).
* **Sponsorship:** Telco CSR funding (Maxis, Celcom, Digi).
* **Donation Fee:** Transparent 2-3% platform fee for maintenance.
* **Premium Tier:** Corporate CSR team management tools.

---

> *"Every year, Malaysian floods don't just destroy homes—they destroy trust. SIGAP rebuilds that trust. We are building the operating system for Malaysia's disaster response."*