# Urban Mobility - Rider App

Mobile application for riders to book and track rides in the urban mobility platform.

## Features

- User registration and authentication
- Real-time location tracking
- Trip booking with multiple vehicle types
- Price negotiation
- Payment via token system
- Trip history and profile management

## Getting Started

### Prerequisites

- Flutter SDK (3.3.4 or higher)
- Android Studio / Xcode
- Backend API running

### Installation

1. Install dependencies:
```bash
cd mobile_rider
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
├── screens/         # UI screens
├── widgets/         # Reusable widgets
├── models/          # Data models
├── services/        # API and business logic services
├── providers/       # State management
└── utils/           # Utilities and constants
```
