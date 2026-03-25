# Salon Owner — Business App

## Project Overview
Flutter mobile app for **salon owners** to manage their salon, accept bookings, track earnings, and receive payouts. Part of the Saloon marketplace platform.

## Tech Stack
- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Storage**: SharedPreferences + FlutterSecureStorage
- **Push Notifications**: Firebase Messaging
- **Chat**: Supabase Realtime
- **Backend**: `saloon-backend` API (shared with salon-user app)

## Key Commands
```bash
flutter pub get                    # Install deps
flutter run                        # Run on connected device
flutter build apk --debug         # Build Android debug APK
```

## Project Structure
```
lib/
├── config/              # API endpoints
├── core/                # Constants, utils, widgets
├── features/
│   ├── auth/            # Phone login (shared with customer app)
│   ├── salon/           # ALL SALON OWNER FEATURES:
│   │   ├── dashboard/   # Stats, revenue, pending bookings
│   │   ├── bookings/    # View/manage salon bookings (confirm, start, complete)
│   │   ├── earnings/    # Revenue, commission breakdown, withdrawal
│   │   ├── profile/     # Salon settings, create/edit salon
│   │   ├── services/    # Add/edit services
│   │   ├── team/        # Manage stylists, availability
│   │   ├── onboarding/  # Payment setup (KYC, bank details, Razorpay Route)
│   │   ├── providers/   # Salon state management
│   │   └── salon_shell.dart  # Bottom nav for salon mode
│   ├── consumer/        # Customer features (NOT used in this app — for salon-user repo)
│   ├── chat/            # Salon-customer messaging
│   ├── notifications/   # Push notifications
│   └── splash/          # Splash + routing
├── services/            # API service
└── main.dart            # App entry, routes
```

## Key Flows (Salon Owner)
1. **Onboarding**: Login → Create salon → Add services → Add stylists → Payment setup (KYC + bank) → Ready
2. **Booking Management**: View bookings → Confirm → Start service → Complete → Collect cash payment (if pay-at-salon)
3. **Earnings**: View revenue/commission breakdown → Request withdrawal to bank
4. **Payment Setup**: 3-step form (business details → PAN/KYC → bank account) → Razorpay linked account → KYC verification
5. **Settlement**: Platform settles weekly (Wed) — salon owner gets push notification with payout amount

## Status: In Progress
This app currently contains code from both customer and salon sides (from the original monorepo). Over time:
- **Keep**: `features/salon/`, `features/auth/`, `features/chat/`, `features/notifications/`
- **Remove**: `features/consumer/` (customer-only features like home, booking, favorites, search)
- **Modify**: `main.dart` routing to only include salon-owner routes
- **Modify**: `splash_screen.dart` to always route to `/salon-home` instead of `/home`

## Coding Conventions
Same as salon-user repo — see that CLAUDE.md for details.

## Related Repos
- **saloon-backend**: Shared backend API (github.com/mihir-kanzariya/saloon-backend)
- **salon-user**: Customer app (github.com/mihir-kanzariya/salon-user)
