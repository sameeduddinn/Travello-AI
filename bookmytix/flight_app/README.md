# Flight App (Travello AI)

Flutter client for the Travello AI booking platform.

## What This App Covers

- Flight, train, and hotel search/booking flows
- Backend-first booking and payment integration with local fallback paths
- Healthcare discovery with OpenStreetMap-based map tiles
- Supabase-backed transactional sync for booking/payment records

## Prerequisites

- Flutter SDK 3.22+
- Dart SDK (bundled with Flutter)
- Android Studio or VS Code Flutter toolchain

## Install Dependencies

```bash
flutter pub get
```

## Run Locally

Use `BACKEND_BASE_URL` to point the app to your backend.

### Android Emulator

```bash
flutter run -d emulator-5554 --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8000
```

### Desktop/Web Local Backend

```bash
flutter run --dart-define=BACKEND_BASE_URL=http://localhost:8000
```

### Remote Backend (Render)

```bash
flutter run --dart-define=BACKEND_BASE_URL=https://travello-backend.onrender.com
```

## Build Web

```bash
flutter build web --release --web-renderer canvaskit \
	--dart-define=BACKEND_BASE_URL=https://travello-backend.onrender.com
```

## Key Directories

- `lib/screens`: UI flows (booking, payment, healthcare, profile, orders)
- `lib/services`: API and transactional service layers
- `lib/models`: data models
- `assets/`: images, fonts, and static resources

## Notes

- Web deployment instructions are in `DEPLOY_WEB.md`.
- This app expects the backend payment endpoints to return `booking_id`, `pnr`, and `transaction_id` when available.
