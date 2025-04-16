FROM ubuntu:24.04

RUN apt update && apt install -y openjdk-17-jdk openjdk-17-jre \ 
    wget git unzip xz-utils zip \
    python3-pip \
    libglu1-mesa libc6:amd64 libstdc++6:amd64 lib32z1 libbz2-1.0:amd64 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV ANDROID_SDK_ROOT="/opt/android-sdk"
ENV ANDROID_HOME="/opt/android-sdk"
ENV PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator"

ARG ANDROID_VERSION=34

RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \ 
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip -O /tmp/cmdline-tools.zip \
    && unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools \
    && mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
    && rm -f /tmp/cmdline-tools.zip \
    && yes | sdkmanager --licenses \
    && sdkmanager "platform-tools" "platforms;android-$ANDROID_VERSION" "build-tools;$ANDROID_VERSION.0.0" "emulator" "system-images;android-$ANDROID_VERSION;google_apis;x86_64" "extras;android;m2repository" "extras;google;m2repository" "extras;google;google_play_services"

ARG FLUTTER_VERSION=3.24.3

RUN wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz -O flutter.tar.xz \
    && tar -xvf flutter.tar.xz -C /opt \
    && rm -f flutter.tar.xz \
    && git config --global --add safe.directory /opt/flutter

ENV PATH="$PATH:/opt/flutter/bin"

RUN flutter doctor && flutter --disable-analytics

ARG INVENTREE_VERSION=0.18.0

RUN git clone https://github.com/inventree/inventree-app.git --branch $INVENTREE_VERSION /inventree-app

WORKDIR /inventree-app

RUN keytool -genkeypair -v -keystore /inventree-app/my-app.keystore -alias my-key-alias -keyalg RSA -keysize 2048 -validity 10000 -storepass testtest -dname "CN=Unknown, OU=Unknown, O=Unknown, L=Unknown, ST=Unknown, C=Unknown"

RUN echo "storeFile=/inventree-app/my-app.keystore\nstorePassword=testtest\nkeyAlias=my-key-alias\nkeyPassword=testtest" > android/key.properties

RUN cd lib/l10n && python3 collect_translations.py

RUN flutter pub get

RUN flutter build apk

FROM scratch

COPY --from=0 /inventree-app/build/app/outputs/flutter-apk/app-release.apk /inventree.apk
