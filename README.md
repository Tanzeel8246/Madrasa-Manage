# Madrasa Ashraf-ul-Madaris Management System

یہ Flutter پر مبنی مدرسہ انتظامی نظام ہے۔ اس میں طلبہ، اساتذہ، حاضری، مالیات، حفظ، امتحانات، رپورٹس، درخواستیں، نوٹس، لاگ اِن، مقامی SQLite ڈیٹابیس اور سرور کے ساتھ ہم آہنگی شامل ہے۔

## بنیادی تقاضے

- Flutter SDK 3.x
- Dart SDK 3.x
- Android Studio یا VS Code
- ایک فعال API server

## پہلی بار چلانے کا طریقہ

```powershell
flutter pub get
flutter run --dart-define=MADRASA_API_URL=https://your-domain.example/
```

اگر API secret واقعی درکار ہو تو اسے source code میں نہ رکھیں:

```powershell
flutter run `
  --dart-define=MADRASA_API_URL=https://your-domain.example/ `
  --dart-define=MADRASA_API_SECRET=your-secret
```

## Release build

```powershell
flutter build apk --release `
  --dart-define=MADRASA_API_URL=https://your-domain.example/ `
  --dart-define=MADRASA_API_SECRET=your-secret
```

## حفاظتی اصول

- API secret، signing keys، `.env`، keystore اور production credentials repository میں commit نہ کریں۔
- Server پر token اور permissions کی validation لازماً برقرار رکھیں۔
- Passwords کو local database یا sync payload میں plain text شکل میں نہ رکھیں۔
- Production secret leak ہو چکا ہو تو اسے server پر rotate کریں۔

## جانچ

```powershell
flutter analyze
flutter test
```

اس project میں critical flows کے لیے مزید tests شامل کرنے چاہییں: login/session، sync conflicts، finance receipts، attendance، exam results اور reports۔

## ساختی رہنمائی

آئندہ development میں بڑی files کو چھوٹے feature modules میں تقسیم کریں:

```text
lib/
  core/
  data/
  features/
  shared/
```

خاص طور پر `db_helper.dart`، `students.dart`، `finance.dart` اور reports screens کو repositories، controllers اور چھوٹے widgets میں تقسیم کرنا project کی پائیداری کے لیے ضروری ہے۔
