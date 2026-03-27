# 🪙 Koin

> **Sleek. Modern. Personal. Your finances, simplified.**

Koin is a sophisticated personal finance tracker built with Flutter, designed to offer a premium and effortless experience for managing your money. With interactive visualizations, multi-account support, and intuitive savings goals, Koin helps you take control of your financial future.

---

## 📥 Download & Releases

Get the latest version of Koin directly from the [GitHub Releases](https://github.com/KlyrhonMiko/koin/releases) page.

[![Download APK](https://img.shields.io/badge/Download-APK-brightgreen?style=for-the-badge&logo=android)](https://github.com/KlyrhonMiko/koin/releases/download/v1.1.0/koin.apk)

> [!TIP]
> **For Android users:** Download the `koin.apk` file, open it on your device, and follow the prompts to install. You may need to enable "Install from Unknown Sources" in your settings.

---

## ✨ Key Features

- **💰 Multi-Account Management**: Effortlessly track and manage multiple accounts, including cash, bank accounts, and savings.
- **📊 Dynamic & Interactive Dashboard**: Gain insights with beautiful, interactive charts and real-time summaries. Tap income/expense cards for quick transaction entry.
- **✨ Premium Visual Experience**: Enjoy a sophisticated, highly animated splash screen with professional glow and particle effects.
- **🔍 Smart Financial Analysis**: Dedicated analysis view featuring expense breakdowns, category rankings, and flexible time-frame filtering (Week/Month/All Time).
- **🚀 Activity-First Approach**: The app defaults to the Analysis view, putting your financial health center stage for immediate awareness.
- **🎯 Savings Tracker**: Set, visualize, and achieve your financial goals with a dedicated tracking system.
- **📂 Categorized Transactions**: Organize your expenses and income with customizable categories for better clarity.
- **🎨 Personalized Themes**: Switch between Dark and Light modes and choose from a set of vibrant accent colors to make the app yours.
- **🔒 Private & Secure**: Your data stays on your device using local SQLite storage for maximum privacy.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (v3.x)
- **State Management**: [Riverpod](https://riverpod.dev)
- **Database**: [SQLite](https://pub.dev/packages/sqflite) via `sqflite`
- **Charts**: [fl_chart](https://pub.dev/packages/fl_chart)
- **Animations**: [flutter_animate](https://pub.dev/packages/flutter_animate)
- **Design**: [Google Fonts (Outfit)](https://fonts.google.com/specimen/Outfit), Custom Glassmorphic & Neumorphic UI
- **Utilities**: `gap`, `shared_preferences`, `intl`, `uuid`, `path_provider`

## 📸 Preview

*Stay tuned for high-resolution screenshots showing off the beautiful UI.*

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/) with Flutter extensions.

### Installation (Development)

To run the project locally for development, follow these steps:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/KlyrhonMiko/koin.git
   cd koin
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   ```bash
   flutter run
   ```

## 📂 Project Structure

```text
lib/
├── core/             # Core utilities, themes, and shared providers
│   ├── models/       # Shared data models
│   ├── providers/    # Global Riverpod providers
│   └── theme.dart    # Central theme configuration
├── features/         # Feature-specific modules
│   ├── accounts/     # Account management logic and UI
│   ├── activity/     # Activity hub (Analysis & Transactions)
│   ├── analysis/     # Financial analysis and charts
│   ├── budgets/      # Budgeting and limits
│   ├── categories/   # Category management
│   ├── dashboard/    # Main overview and interactive cards
│   ├── savings/      # Savings goals tracker
│   ├── settings/     # App configurations and preferences
│   └── transactions/ # Transaction history and creation
└── main.dart         # Entry point and global configuration
```

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="center">
  Built with ❤️ by <a href="https://github.com/KlyrhonMiko">KlyrhonMiko</a>
</p>
