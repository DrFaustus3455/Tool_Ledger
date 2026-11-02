# Multi-stage build: compile Flutter web, serve with hardened nginx.
# Build:  docker build --build-arg API_BASE_URL=https://api.example.com -t toolledger-web .
# Run:    docker run -p 8080:8080 toolledger-web
FROM ghcr.io/cirruslabs/flutter:stable AS build
ARG API_BASE_URL=https://api.example.com
ARG DATA_SOURCE=live
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release --no-web-resources-cdn \
    --dart-define=DATA_SOURCE=${DATA_SOURCE} \
    --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginxinc/nginx-unprivileged:stable-alpine
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 8080
