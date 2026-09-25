FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
COPY packages ./packages
RUN flutter pub get
COPY . .
RUN flutter build web --release

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/build/web /usr/share/nginx/html
