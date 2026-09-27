# Kagami Server. Si costruisce dalla radice del repo, perché il server usa il
# motore di packages/kagami_archive:
#   docker build -f server/Dockerfile -t kagami-server .
#   docker build -f server/Dockerfile --target test .   # i test, con libvips

FROM dart:stable AS build
WORKDIR /src
COPY packages/kagami_archive packages/kagami_archive
COPY server server
WORKDIR /src/server
RUN dart pub get && dart compile exe bin/kagami_server.dart -o /kagami-server

# Qui girano anche i test di miniature e tessere, che fuori si saltano dove
# libvips manca.
FROM build AS test
RUN apt-get update && apt-get install -y --no-install-recommends libvips-tools \
    && rm -rf /var/lib/apt/lists/*
RUN cd /src/packages/kagami_archive && dart test && cd /src/server && dart analyze --fatal-infos && dart test

FROM debian:trixie-slim
# libvips per miniature e tessere, i certificati per parlare con Google e con
# i siti, tzdata perché il controllo delle serie in corso va all'ora di TZ.
RUN apt-get update && apt-get install -y --no-install-recommends libvips-tools ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --uid 1000 --create-home kagami \
    && mkdir /data && chown kagami:kagami /data
COPY --from=build /kagami-server /usr/local/bin/kagami-server
USER kagami
ENV KAGAMI_DATA=/data
VOLUME /data
EXPOSE 8080
HEALTHCHECK --interval=1m --timeout=10s --start-period=30s --start-interval=5s CMD ["kagami-server", "ping"]
ENTRYPOINT ["kagami-server"]
CMD ["serve"]
