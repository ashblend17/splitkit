# The app (Flutter)

Android, iOS and Web from one codebase.

```
lib/
  core/            config, api (generated client wrapper), money, splits (pure engine),
                   theme (tokens.g.dart + typography + ThemeData), router
  design_system/   presentational widgets; see /gallery
  features/        screens (build step 5 onwards); gallery/ is the component gallery
packages/
  api_client/      generated from api/openapi.json by tool/gen_api_client.sh; don't edit
```

```sh
flutter test
flutter run -d chrome --dart-define=API_ORIGIN=http://localhost:8000
flutter run -d emulator-5554 --dart-define=API_ORIGIN=http://10.0.2.2:8000
flutter build apk --debug --dart-define=API_ORIGIN=http://10.0.2.2:8000
```

`API_ORIGIN` is only the default. Debug builds have a **Server: …** link under the login form that
switches the API at runtime (saved on the device; switching logs you out). Add
`--dart-define=DEV_TOOLS=true` to get it in a profile or release build.

Fonts (Bricolage Grotesque, Instrument Sans) are bundled variable fonts under `assets/fonts`
(SIL Open Font License), so the app never fetches fonts at runtime.
