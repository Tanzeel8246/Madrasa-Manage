# Madrasa App Release Checklist

## Required local build variables

Pass these values when building a release:

```powershell
flutter build appbundle --release `
  --dart-define=MADRASA_API_URL=https://madrasa.mamfss.com/ `
  --dart-define=MADRASA_API_SECRET=your-long-random-api-secret
```

## Required server environment variables

Configure these on the live server before deploying the patched PHP app:

```text
MADRASA_IS_PRODUCTION=true
MADRASA_DB_HOST=localhost
MADRASA_DB_PORT=
MADRASA_DB_NAME=mamfss_madrasa
MADRASA_DB_USER=mamfss_madrasa
MADRASA_DB_PASSWORD=your-rotated-db-password
MADRASA_API_SECRET=your-long-random-api-secret
MOCEAN_API_TOKEN=your-rotated-sms-token
```

## Play Store must-haves

- Generate a private upload keystore and create `android/key.properties` from `android/key.properties.example`.
- Rotate every secret that was previously committed or shipped in an APK.
- Publish a privacy policy URL and complete Play Console Data Safety accurately.
- Declare microphone usage only if voice input remains a user-facing feature.
- Run `flutter analyze`, `flutter test`, and `flutter build appbundle --release` before upload.
