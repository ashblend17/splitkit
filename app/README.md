# Splitkit app (Flutter)

Android, iOS and Web from one codebase.

```
lib/
  core/            config, api (generated client wrapper), money, splits (pure engine),
                   theme (tokens.g.dart + typography + ThemeData), router
  design_system/   presentational widgets; see /gallery
  features/        screens (build step 5 onwards); gallery/ is the component gallery
packages/
  splitkit_api/    generated from api/openapi.json by tool/gen_api_client.sh; don't edit
```

```sh
flutter test
flutter run -d chrome --dart-define=API_ORIGIN=http://localhost:8000
flutter run -d emulator-5554 --dart-define=API_ORIGIN=http://10.0.2.2:8000
```

Fonts (Bricolage Grotesque, Instrument Sans) are bundled variable fonts under `assets/fonts`
(SIL Open Font License), so the app never fetches fonts at runtime.
