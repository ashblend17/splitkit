FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
COPY packages ./packages
RUN flutter pub get
COPY . .
# tool/build.sh passes the build number (the commit count) and the app's name; the version is
# pubspec.yaml's. The page's title and the manifest take the name too.
ARG BUILD_NUMBER=0
ARG APP_NAME=App
RUN flutter build web --release --build-number=$BUILD_NUMBER --dart-define=BUILD_NUMBER=$BUILD_NUMBER \
      --dart-define=APP_NAME="$APP_NAME" \
 && sed -i "s/__APP_NAME__/$APP_NAME/g" build/web/index.html build/web/manifest.json

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/build/web /usr/share/nginx/html
