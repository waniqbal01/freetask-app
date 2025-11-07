# Development Notes

## Web Dev

Run the Flutter web app against the local API with:

```
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

If you later enable cookies or other credentialed requests, ensure the Express server sets `WEB_ORIGIN` to the Flutter dev URL (for example, `http://127.0.0.1:64081`).
