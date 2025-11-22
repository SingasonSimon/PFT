# Personal Finance Tracker (PFT)

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.2.3+-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.2.3+-0175C2?logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-5.0+-FFCA28?logo=firebase&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-green.svg)

A modern, feature-rich Flutter application for managing your personal finances. Track income, expenses, bills, and generate comprehensive financial reports with beautiful visualizations.

[Features](#-features) • [Installation](#-installation) • [Setup](#-setup) • [Usage](#-usage) • [Tech Stack](#-tech-stack)

</div>

---

## 📱 Overview

Personal Finance Tracker (PFT) is a comprehensive mobile application designed to help you take control of your finances. Built with Flutter and Firebase, it provides a seamless experience for tracking your income, managing expenses, monitoring bills, and analyzing your financial health through interactive charts and reports.

### Key Highlights

- 💰 **Complete Financial Management** - Track all your income and expenses in one place
- 📊 **Visual Analytics** - Interactive charts and graphs for better financial insights
- 🔔 **Bill Reminders** - Never miss a payment with smart bill tracking
- ☁️ **Cloud Sync** - Your data is safely backed up and synced across devices
- 🔒 **Secure** - Firebase Authentication ensures your data is protected
- 🎨 **Modern UI** - Beautiful Material 3 design with a clean, intuitive interface

---

## ✨ Features

### 💵 Transaction Management
- **Add Transactions**: Quickly record income and expenses with detailed categorization
- **Edit & Delete**: Modify or remove transactions with swipe gestures
- **Search & Filter**: Find specific transactions by description, amount, category, or date range
- **Transaction History**: View all your transactions in a clean, organized list

### 📁 Category Management
- **Custom Categories**: Create personalized income and expense categories
- **Category Icons**: Choose from a variety of icons for better visual organization
- **Category Colors**: Assign colors to categories for quick identification
- **Full CRUD Operations**: Create, read, update, and delete categories seamlessly

### 💳 Bill Tracking
- **Recurring Bills**: Set up weekly or monthly recurring bills
- **Bill Reminders**: Get notified about upcoming bill payments
- **Payment Tracking**: Mark bills as paid and track payment history
- **Due Date Management**: Never miss a payment with clear due date indicators

### 📈 Financial Reports
- **Income vs Expenses**: Visual comparison with bar charts
- **Expense Breakdown**: Pie charts showing spending by category
- **Net Income Analysis**: Track your financial health over time
- **Time Period Filters**: Analyze data by week, month, or year
- **PDF Export**: Generate and share detailed financial reports

### 👤 User Management
- **Secure Authentication**: Email and password authentication via Firebase
- **Profile Management**: Update your name and profile picture
- **Currency Selection**: Choose your preferred currency (KSh, USD, EUR, GBP)
- **Data Backup & Restore**: Sync your data to Firebase Cloud Firestore

### 🔐 Security Features
- **Passcode Protection**: Add an extra layer of security with app passcode
- **Biometric Authentication**: Use fingerprint or face ID (where supported)
- **Cloud Backup**: Automatic data synchronization to Firebase

### 🎨 User Experience
- **Modern Material 3 Design**: Beautiful, intuitive interface
- **Green Theme**: Consistent color scheme throughout the app
- **Responsive Layout**: Optimized for all screen sizes
- **Smooth Animations**: Polished transitions and interactions
- **Offline Support**: Works offline with local SQLite database

---

## 🚀 Installation

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (3.2.3 or higher)
- **Dart SDK** (3.2.3 or higher)
- **Android Studio** / **Xcode** (for mobile development)
- **Firebase Account** (for authentication and cloud sync)
- **Git** (for version control)

### Step 1: Clone the Repository

```bash
git clone https://github.com/SingasonSimon/PFT.git
cd PFT
```

### Step 2: Install Dependencies

```bash
flutter pub get
```

### Step 3: Firebase Setup

1. **Create a Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project or use an existing one
   - Enable **Authentication** → **Email/Password**

2. **Configure Android**
   - Download `google-services.json` from Firebase Console
   - Place it in `android/app/google-services.json`

3. **Configure iOS** (if developing for iOS)
   - Download `GoogleService-Info.plist` from Firebase Console
   - Place it in `ios/Runner/GoogleService-Info.plist`

4. **Enable Cloud Firestore**
   - In Firebase Console, go to **Firestore Database**
   - Create database in **test mode** (or production mode with proper security rules)

### Step 4: Configure Cloudinary (for Profile Images)

1. Create a [Cloudinary](https://cloudinary.com/) account
2. Update `lib/helpers/config.dart` with your Cloudinary credentials:
   ```dart
   class AppConfig {
     static const String cloudinaryCloudName = 'your_cloud_name';
     static const String cloudinaryApiKey = 'your_api_key';
     static const String cloudinaryApiSecret = 'your_api_secret';
   }
   ```

### Step 5: Run the App

```bash
# For Android
flutter run

# For iOS
flutter run -d ios

# For a specific device
flutter devices  # List available devices
flutter run -d <device_id>
```

---

## 📖 Usage

### Getting Started

1. **Welcome Screen**: First-time users will see a welcome screen
2. **Sign Up**: Create an account with your email and password
3. **Sign In**: Use your credentials to access your account

### Adding Transactions

1. Tap the **"Add Transaction"** floating action button on the home screen
2. Select transaction type (Income or Expense)
3. Enter amount and description
4. Choose a category (or create a new one)
5. Select date
6. Tap **"Save Transaction"**

### Managing Categories

1. Navigate to **Profile** → **Manage Categories**
2. Tap **"+"** to add a new category
3. Enter category name, select type (Income/Expense), and choose an icon
4. Tap **"Save"** to create the category

### Setting Up Bills

1. Go to **Home** → **Upcoming Bills** section
2. Tap **"Add Bill"**
3. Enter bill name, amount, and due date
4. Enable **"Recurring Bill"** if needed
5. Select recurrence type (Weekly or Monthly)
6. Tap **"Save Bill"**

### Viewing Reports

1. Navigate to the **Reports** tab
2. Select time period (Week, Month, or Year)
3. View:
   - Net Income summary
   - Income vs Expenses bar chart
   - Expense breakdown pie chart
4. Tap **"Export Report"** to generate a PDF

### Profile Settings

1. Go to **Profile** tab
2. **Update Name**: Tap the edit icon next to your name
3. **Change Profile Picture**: Tap your profile picture to upload a new one
4. **Change Currency**: Select your preferred currency
5. **Set Passcode**: Enable app passcode for extra security
6. **Backup & Restore**: Sync your data to/from Firebase

---

## 🛠️ Tech Stack

### Frontend
- **Flutter** - Cross-platform UI framework
- **Dart** - Programming language
- **Material 3** - Modern design system

### Backend & Services
- **Firebase Authentication** - User authentication
- **Cloud Firestore** - Cloud database and sync
- **Cloudinary** - Image storage and management

### Local Storage
- **SQLite (sqflite)** - Local database for offline support
- **SharedPreferences** - User preferences and settings

### State Management
- **Provider** - State management
- **ValueNotifier** - Local state management

### UI Components
- **fl_chart** - Beautiful charts and graphs
- **google_fonts** - Custom typography
- **intl** - Internationalization and formatting

### Additional Packages
- **image_picker** - Profile picture selection
- **url_launcher** - External links (WhatsApp support)
- **flutter_local_notifications** - Bill reminders
- **pdf** & **printing** - Report generation
- **crypto** - Secure image upload signatures

---

## 📁 Project Structure

```
lib/
├── auth_gate.dart              # Authentication routing
├── main.dart                    # App entry point and navigation
├── firebase_options.dart        # Firebase configuration
│
├── helpers/
│   ├── config.dart             # App configuration (Cloudinary)
│   ├── database_helper.dart    # SQLite database operations
│   ├── date_picker_helper.dart # Modern date picker
│   ├── dialog_helper.dart      # Reusable dialog components
│   ├── notification_service.dart # Bill reminders
│   └── pdf_helper.dart         # PDF report generation
│
├── models/
│   ├── bill.dart               # Bill data model
│   ├── category.dart           # Category data model
│   └── transaction.dart       # Transaction data model
│
└── screens/
    ├── welcome_screen.dart     # Onboarding screen
    ├── login_screen.dart       # User login
    ├── signup_screen.dart      # User registration
    ├── home_screen.dart        # Main dashboard
    ├── add_transaction_screen.dart
    ├── transaction_detail_screen.dart
    ├── all_transactions_screen.dart
    ├── manage_categories_screen.dart
    ├── add_bill_screen.dart
    ├── reports_screen.dart      # Financial reports
    ├── profile_screen.dart     # User settings
    └── passcode_screen.dart    # Passcode setup/verification
```

---

## 🔧 Configuration

### Firebase Setup

1. **Authentication**
   - Enable Email/Password authentication in Firebase Console
   - No additional configuration needed

2. **Firestore Database**
   - Create database in test mode for development
   - Structure: `users/{userId}/transactions/{transactionId}`
   - Structure: `users/{userId}/categories/{categoryId}`
   - Structure: `users/{userId}/bills/{billId}`

3. **Security Rules** (Production)
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

### Cloudinary Setup

1. Sign up at [cloudinary.com](https://cloudinary.com/)
2. Get your Cloud Name, API Key, and API Secret
3. Update `lib/helpers/config.dart` with your credentials

---

## 🧪 Development

### Running Tests

```bash
flutter test
```

### Code Analysis

```bash
flutter analyze
```

### Building for Production

**Android:**
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

### Generating App Icons

The app uses `flutter_launcher_icons` for icon generation:

```bash
flutter pub run flutter_launcher_icons
```

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Style

- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Run `dart format .` before committing
- Ensure `flutter analyze` passes without errors

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Singason Simon**

- GitHub: [@SingasonSimon](https://github.com/SingasonSimon)
- Repository: [PFT](https://github.com/SingasonSimon/PFT)

---

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- All open-source package contributors
- Material Design team for the design system

---

## 📞 Support

For support, questions, or feature requests:

- 📧 Email: Contact via GitHub
- 💬 WhatsApp: +254 713 561 800
- 🐛 Issues: [GitHub Issues](https://github.com/SingasonSimon/PFT/issues)

---

## 🔮 Future Enhancements

- [ ] Multi-currency support with exchange rates
- [ ] Budget planning and tracking
- [ ] Recurring transaction templates
- [ ] Data export (CSV, Excel)
- [ ] Dark mode support
- [ ] Biometric authentication
- [ ] Widget support for quick transaction entry
- [ ] Advanced analytics and insights
- [ ] Goal setting and tracking
- [ ] Receipt scanning with OCR

---

<div align="center">

**Made with ❤️ using Flutter**

⭐ Star this repo if you find it helpful!

</div>
