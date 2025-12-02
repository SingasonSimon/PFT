# Personal Finance Tracker (PFT)

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.22+-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.4+-0175C2?logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%26%20Firestore-FFCA28?logo=firebase&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-green.svg)

**Comprehensive  documentation for the Personal Finance Tracker mobile app.**

[Overview](#overview) • [Architecture](#system-architecture) • [Tech Stack](#tech-stack) • [Setup](#setup--deployment) • [Usage](#feature-guide) • [Testing](#quality-assurance) • [Support](#support)

</div>

---

## Overview

The Personal Finance Tracker (PFT) is a cross-platform Flutter application that helps individuals record transactions, manage bills, analyze expenses, and monitor financial health from a single interface. The project intentionally focuses on educational clarity: the codebase demonstrates clean architecture principles, modern UI/UX, Firebase integration, and offline-first patterns suitable for student projects and professional portfolios.

### Objectives
- Provide a practical case study for Flutter + Firebase driven applications.
- Demonstrate end-to-end mobile app delivery (design, development, deployment).
- Serve as starter material for coursework, documentation practice, and code reviews.

### Success Metrics
- **Reliability:** Seamless auth + persistent sessions after app restarts.
- **Productivity:** Sub-5 second cold start, <2 second major navigation transitions.
- **Data Integrity:** Transactions synced across devices within 1 second (Wi-Fi).

---

## System Architecture

```
┌──────────────────┐
│   Presentation    │
│ (Flutter Screens) │
└────────┬─────────┘
         │
         │ Provider / ValueNotifier
         ▼
┌──────────────────┐
│  Application     │
│  Services Layer  │  ← dialog helpers, date pickers, notification orchestration
└────────┬─────────┘
         │
         │ Repository Pattern
         ▼
┌──────────────────┐           ┌────────────────────┐
│ Local Persistence │◀────────▶│   Cloud Services    │
│ (SQLite, Shared   │          │ Firebase Auth +     │
│ Preferences)      │          │ Cloud Firestore     │
└──────────────────┘           └────────────────────┘
```

- **Authentication flow:** `AuthGate` listens to Firebase auth stream, then defers to `PasscodeScreen` when local lock is enabled.
- **Data flow:** Transactions, bills, and categories are stored locally (SQLite) for offline use, then mirrored to Cloud Firestore per authenticated user.
- **Images:** Uploaded to Cloudinary with signed URLs and cache-busting headers to prevent stale profile photos.
- **Notifications:** Managed through `flutter_local_notifications` with bill reminders scheduled from SQLite data.

---

## Tech Stack

| Layer | Technology | Purpose |
| --- | --- | --- |
| Framework | Flutter (Material 3) | Cross-platform UI |
| Language | Dart | Application logic |
| Auth | Firebase Authentication | Secure login & session mgmt |
| Database (Cloud) | Cloud Firestore | Multi-device sync |
| Database (Local) | SQLite (`sqflite`) | Offline access & caching |
| Storage | Cloudinary | Profile image hosting |
| State Mgmt | Provider, ValueNotifier | Lightweight and explicit state flow |
| Notifications | `flutter_local_notifications` | Bill reminders |
| Reporting | `fl_chart`, `pdf`, `printing` | Analytics & export |
| Utilities | `intl`, `crypto`, `image_picker`, `url_launcher` | Formatting, signatures, media, deep links |

> Full dependency list lives in `pubspec.yaml`.

---

## Repository Layout

```
lib/
├── auth_gate.dart                # Auth + passcode routing
├── main.dart                     # App shell, navigation, theming
├── firebase_options.dart         # Generated Firebase config
│
├── helpers/
│   ├── config.dart               # Cloudinary + app constants
│   ├── database_helper.dart      # SQLite access + migrations
│   ├── date_picker_helper.dart   # Consistent Material date pickers
│   ├── dialog_helper.dart        # Snackbar/toast/dialog utilities
│   ├── notification_service.dart # Bill reminder scheduling
│   └── pdf_helper.dart           # PDF export logic
│
├── models/
│   ├── bill.dart
│   ├── category.dart
│   └── transaction.dart
│
└── screens/
    ├── welcome_screen.dart
    ├── login_screen.dart
    ├── signup_screen.dart
    ├── home_screen.dart
    ├── add_transaction_screen.dart
    ├── transaction_detail_screen.dart
    ├── all_transactions_screen.dart
    ├── manage_categories_screen.dart
    ├── add_bill_screen.dart
    ├── reports_screen.dart
    ├── profile_screen.dart
    └── passcode_screen.dart
```

---

## Feature Guide

| Module | Capabilities | Key Files |
| --- | --- | --- |
| Transactions | CRUD, filtering, timeline view | `add_transaction_screen.dart`, `all_transactions_screen.dart` |
| Categories | Icon & color picker, duplication guard | `manage_categories_screen.dart` |
| Bills | Recurrence, reminders, paid history | `add_bill_screen.dart`, `notification_service.dart` |
| Reports | Income vs expense, category breakdown, PDF export | `reports_screen.dart`, `pdf_helper.dart` |
| Profile | Photo upload (Cloudinary), currency, WhatsApp support | `profile_screen.dart`, `config.dart` |
| Security | Firebase Auth, passcode unlock, optional biometrics | `auth_gate.dart`, `passcode_screen.dart` |

UX staples include consistent input theming, animated dialogs, loading overlays, disabled buttons during network calls, and Snackbar-driven feedback.

---

## Setup & Deployment

### 1. System Prerequisites
- Flutter SDK 3.22+
- Dart SDK 3.4+
- Android Studio / Xcode /VS Code
- Firebase project with Auth + Firestore enabled
- Cloudinary account for media storage

### 2. Clone & Install
```bash
git clone https://github.com/SingasonSimon/PFT.git
cd PFT
flutter pub get
```

### 3. Firebase Configuration
1. Create/Select Firebase project.
2. Enable Email/Password Authentication.
3. Add Android app → download `google-services.json` → place in `android/app/`.
4. (Optional) Add iOS app → place `GoogleService-Info.plist` in `ios/Runner/`.
5. Create Cloud Firestore database (test mode for development).

**Security rules (production baseline):**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 4. Cloudinary Credentials
Update `lib/helpers/config.dart`:
```dart
class AppConfig {
  static const cloudinaryCloudName = 'your_cloud_name';
  static const cloudinaryApiKey = 'your_api_key';
  static const cloudinaryApiSecret = 'your_api_secret';
}
```

### 5. Run
```bash
flutter run               # auto device
flutter run -d chrome     # web (if enabled)
flutter run -d <device>   # specific emulator/phone
```

### 6. Production Builds
```bash
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
```

---

## Quality Assurance

| Area | Command | Notes |
| --- | --- | --- |
| Static analysis | `flutter analyze` | Lint clean before PRs |
| Unit / widget tests | `flutter test` | Expand coverage for regressions |
| Integration tests | `flutter test integration_test` | Optional, not yet scripted |
| Formatting | `dart format .` | Enforced in CI/CD flow |

**Manual QA checklist**
- [ ] Login → logout → login flow without app restart delays
- [ ] Add/Edit/Delete transaction while offline then reconnect
- [ ] Category creation prevents duplicates and clears state
- [ ] Bill reminder fires at scheduled time (use test notification)
- [ ] Profile photo persists after closing and reopening app
- [ ] PDF report export from Reports tab

---

## Operational Playbook

### Troubleshooting
| Scenario | Resolution |
| --- | --- |
| Login spinner never stops | Confirm Firebase credentials + internet. Check `login_screen.dart` for `_isLoading` states. |
| Profile image reverts | Ensure Cloudinary credentials are set and device clock is correct (signature uses timestamp). |
| Infinite loading dialogs | Use `ValueNotifier<bool>` pattern. Verify buttons disabled when `isLoading == true`. |
| Firestore permission errors | Update security rules or confirm user UID matches document path. |
| Gradle Java version warnings | Project targets Java 17. Re-run `flutter clean` if migrating from older SDK. |

### Maintenance Tasks
- Rotate Cloudinary credentials annually.
- Review Firebase security rules quarterly.
- Audit shared preferences & SQLite migrations before major releases.
- Regenerate launcher icons after branding updates (`flutter pub run flutter_launcher_icons`).

---

## Contribution Guidelines

1. Fork repository and create feature branch (`git checkout -b feature/<name>`).
2. Run `flutter analyze` and `flutter test`.
3. Document UI/UX changes with screenshots in PR when possible.
4. Submit pull request with clear description + testing notes.

**Coding Standards**
- Follow Effective Dart style guide.
- Keep widgets small; prefer composition over inheritance.
- Avoid synchronous long-running operations in UI thread; use async/await with proper error handling.

---

## License

MIT License – see [`LICENSE`](LICENSE) for full text.

---

## Maintainer

**Singason Simon**  
- GitHub: [@SingasonSimon](https://github.com/SingasonSimon)  
- Project repo: [PFT](https://github.com/SingasonSimon/PFT)



---

## Acknowledgements
- Flutter & Dart teams for the core tooling.
- Firebase team for the managed backend platform.
- Community package authors (`fl_chart`, `pdf`, `flutter_local_notifications`, etc.).

---

## Support

| Channel | Details |
| --- | --- |
| Issues | GitHub Issues tab |
| Email | Reach via GitHub profile |

---

## Roadmap

- [ ] Budget planning module with alerts
- [ ] Collaborative accounts / shared wallets
- [ ] OCR-based receipt scanning
- [ ] Expanded analytics (cashflow forecasting, savings goals)
- [ ] Multi-currency with live FX rates
- [ ] Homescreen widgets and quick actions

---

<div align="center">

**Crafted with care using Flutter.**  
If this documentation helped you, kindly star the repository!

</div>
