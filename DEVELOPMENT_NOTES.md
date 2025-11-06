# Freetask – Quick Dev Networking Notes

## Backend (Express)
Run (Linux/Mac):
```bash
HOST=0.0.0.0 PORT=4000 node index.js
```
Verify API health:
```bash
curl http://127.0.0.1:4000/healthz
```

## Flutter App
Run (web):
```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

Run (Android emulator):
```bash
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000
```

Check Dio base URL at runtime:
```bash
flutter pub run build_runner build
# then inspect logs for [DIO][TYPE] entries during network requests
```
