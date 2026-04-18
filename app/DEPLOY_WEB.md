# Flutter Web Deployment — Travello AI (FYP Demo)

## Prerequisites
- Flutter SDK installed and `flutter doctor` passes
- Node.js + npm installed (for Firebase CLI)
- A Firebase project OR a Netlify account (both free)

---

## Step 1 — Build the Web Bundle

```bash
cd flight_app

# Use canvaskit renderer for best visual fidelity (matches mobile)
flutter build web --release --web-renderer canvaskit
```

The output lands in `build/web/`.

---

## Step 2A — Deploy to Firebase Hosting (recommended)

```bash
# Install Firebase CLI (once)
npm install -g firebase-tools

# Log in
firebase login

# Initialise hosting (run from flight_app/ root)
firebase init hosting
# → Select your Firebase project
# → Public directory: build/web
# → Single-page app: YES
# → Do NOT overwrite build/web/index.html

# Deploy
firebase deploy --only hosting
```

Your app is live at: `https://<project-id>.web.app`

---

## Step 2B — Deploy to Netlify (easier, no CLI needed)

1. Run `flutter build web --release --web-renderer canvaskit`
2. Drag the **`build/web`** folder to [netlify.com/drop](https://app.netlify.com/drop)
3. Done — live URL appears in 30 seconds

To redeploy: drag the folder again or use Netlify CLI (`netlify deploy --prod --dir build/web`).

---

## Step 3 — Point the App to Your Deployed Backend

The app now reads the backend URL from a Dart define.

Use this when building/deploying web:

```bash
flutter build web --release --web-renderer canvaskit \
	--dart-define=BACKEND_BASE_URL=https://travello-backend.onrender.com
```

For local Android emulator testing:

```bash
flutter run -d emulator-5554 --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8000
```

---

## Known Limitations on Web

| Feature | Status |
|---|---|
| GPS / location | Requires HTTPS (works on Firebase/Netlify, **not** on localhost) |
| Camera / image picker | Limited — needs `image_picker` web plugin |
| Push notifications | Not supported on Flutter Web |
| Deep links | Requires `url_strategy` package + server-side redirect rules |
| Google Maps | Add to `web/index.html`: `<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_KEY"></script>` |

---

## Add Google Maps Support (optional)

In `web/index.html`, inside `<head>`:

```html
<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_GOOGLE_MAPS_KEY"></script>
```

Get a free key at [Google Cloud Console](https://console.cloud.google.com) →
APIs & Services → Enable **Maps JavaScript API** → Credentials.

---

## Useful Commands

```bash
# Serve locally to test web build
flutter run -d chrome

# Build for web with HTML renderer (faster, less accurate)
flutter build web --web-renderer html

# Check build size
du -sh build/web/

# Analyse bundle
flutter build web --analyze-size
```
