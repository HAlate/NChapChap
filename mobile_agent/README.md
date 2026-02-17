# Urban Mobility - Driver App

Mobile application for drivers to accept and manage ride requests in the urban mobility platform.

## Features

- Driver registration and authentication
- Real-time availability status management
- Trip request notifications
- Accept/reject ride requests (token-based)
- Token management and purchase
- Trip history and earnings tracking

## Getting Started

### Prerequisites

- Flutter SDK (3.3.4 or higher)
- Android Studio / Xcode
- Backend API running

### Installation

1. Install dependencies:
```bash
cd mobile_driver
flutter pub get
```

2. Configure API endpoint in `lib/services/api_service.dart`

3. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── screens/         # UI screens for drivers
├── widgets/         # Reusable widgets
├── models/          # Data models
├── services/        # API and business logic services
└── utils/           # Utilities and constants
```

## Token System

Drivers purchase tokens to accept trip requests. Each accepted trip consumes 1 token.
