# Development Notes

## Web Dev

Run the Flutter web app against the local API with:

```
flutter run -d chrome --web-hostname=127.0.0.1 --web-port=54879 --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

Keep the same `127.0.0.1` origin for both Flutter and the Express API so that CORS stays aligned. If you later enable cookies or other credentialed requests, ensure the Express server sets `WEB_ORIGIN` to the Flutter dev URL (for example, `http://127.0.0.1:54879`).
