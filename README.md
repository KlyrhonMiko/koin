# Koin

A sophisticated, modern, and interactive personal finance tracker built with Flutter.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Riverpod](https://img.shields.io/badge/Riverpod-000000?style=for-the-badge&logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)

## Overview

Koin is designed to offer a premium and effortless experience for managing your money. With interactive visualizations, multi-account support, and intuitive savings goals, Koin helps you take control of your financial future. The architecture focuses on privacy, storing all data locally on your device.

## What's New (v1.1.1)

- **Redesigned Debts Page**: Improved clarity and tracking for managing debts.
- **Performance**: Upgraded Gradle configuration and minor bug fixes for smoother operation.

## Key Features

- **Multi-Account Management**: Effortlessly track and manage cash, bank accounts, and savings.
- **Interactive Dashboard**: Gain insights with beautiful charts, real-time summaries, and an activity-first approach.
- **Savings Tracker**: Set, visualize, and achieve your financial goals.
- **Financial Analysis**: Deep dive with expense breakdowns, category rankings, and time-frame filtering.
- **Personalized UI**: Dark and light modes with vibrant accent colors, plus glassmorphic and neumorphic elements.
- **Private & Secure**: Your data stays on your device using local SQLite storage.

## Technologies Used

- **Framework**: [Flutter](https://flutter.dev/) (v3.x)
- **Language**: [Dart](https://dart.dev/)
- **State Management**: [Riverpod](https://riverpod.dev/)
- **Database**: [SQLite](https://pub.dev/packages/sqflite)
- **Charts**: [fl_chart](https://pub.dev/packages/fl_chart)
- **Animations**: [flutter_animate](https://pub.dev/packages/flutter_animate)

## Download

Get the latest version directly from our [GitHub Releases](https://github.com/KlyrhonMiko/koin/releases).

[![Download APK](https://img.shields.io/badge/Download_APK_v1.1.1-4CAF50?style=for-the-badge&logo=android&logoColor=white)](https://github.com/KlyrhonMiko/koin/releases/download/v1.1.1/koinv1.1.1.apk)

> [!TIP]
> **For Android users:** Download the `koin.apk` file, open it on your device, and follow the prompts to install. You may need to enable "Install from Unknown Sources" in your settings.

## Getting Started

To run this project locally, follow these steps:

1. **Clone the repository**
   ```bash
   git clone https://github.com/KlyrhonMiko/koin.git
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   flutter run
   ```

## Project Structure

- `/lib/core`: Core utilities, themes, and shared models/providers.
- `/lib/features`: Feature-specific modules (accounts, analysis, dashboard, savings).
- `/lib/main.dart`: Entry point and global configuration.
