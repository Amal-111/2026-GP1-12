# RASD

This repository contains the Flutter Android app and the Firebase backend for the RASD graduation project.

- `mobile_app/RASD_app/` contains the Flutter app and automated tests.
- `backend/` contains the TypeScript Cloud Functions and Firebase configuration and rules.

From the Flutter app directory, run `flutter pub get`, `flutter analyze`, `flutter test` and `flutter build apk --debug`. From `backend/functions/`, run `npm ci`, `npm run lint` and `npm run build` using Node.js 24. Local integration uses the Firebase Emulators. The checked-in Firebase client settings identify the existing project. Keep service credentials, local secrets, and emulator exports outside version control.
