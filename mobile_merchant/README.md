# Urban Mobility - Merchant App

Mobile application for merchants to manage their products, orders, and deliveries in the urban mobility platform.

## Features

- Merchant registration and authentication
- Product catalog management (add, edit, delete, availability)
- Order management with status tracking
- Real-time order notifications
- Business profile management
- Order status workflow:
  - Pending → Preparing → Ready → Delivering → Delivered
  - Cancel option at any stage

## Getting Started

### Prerequisites

- Flutter SDK (3.3.4 or higher)
- Android Studio / Xcode
- Backend API running

### Installation

1. Install dependencies:
```bash
cd mobile_merchant
flutter pub get
```

2. Configure API endpoint in `lib/services/merchant_api_service.dart`

3. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── screens/         # UI screens for merchants
│   ├── merchant_login_screen.dart
│   ├── merchant_register_screen.dart
│   ├── merchant_home_screen.dart
│   ├── merchant_orders_screen.dart
│   ├── merchant_products_screen.dart
│   └── merchant_profile_screen.dart
├── widgets/         # Reusable widgets
├── models/          # Data models (Merchant, Product, Order)
├── services/        # API and business logic services
├── providers/       # State management
└── utils/           # Utilities and constants
```

## Business Categories

Supported merchant categories:
- Restaurant
- Épicerie (Grocery)
- Pharmacie (Pharmacy)
- Boulangerie (Bakery)
- Fast Food
- And more...

## Order Status Flow

1. **Pending** - New order received
2. **Preparing** - Merchant is preparing the order
3. **Ready** - Order ready for pickup
4. **Delivering** - Driver is delivering the order
5. **Delivered** - Order completed
6. **Cancelled** - Order cancelled by merchant or customer
