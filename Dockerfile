FROM ubuntu:24.04 AS flutter-build

ARG FLUTTER_VERSION=3.47.6
ARG APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY

ENV FLUTTER_ROOT=/opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      libglu1-mesa \
      unzip \
      xz-utils \
      zip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      -o /tmp/flutter.tar.xz \
    && tar -xJf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

RUN if [ -z "${APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY}" ]; then \
      echo "Set APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY in Render." >&2; \
      exit 1; \
    fi \
    && flutter build web --release \
      --dart-define=APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY="${APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY}"

FROM nginx:stable-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=flutter-build /app/build/web /usr/share/nginx/html

EXPOSE 10000
