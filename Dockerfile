FROM debian:trixie-slim

RUN apt-get update
COPY scripts/install-base-packages.sh .

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    ./install-base-packages.sh && rm install-base-packages.sh

RUN mkdir -p /app/test
COPY app/cleanup /app/cleanup
COPY app/cleanup-fns.sh /app/cleanup-fns.sh
RUN chmod 0755 /app/cleanup

COPY app/test/test_cleanup /app/test/test_cleanup
COPY app/test/test.env /app/test/test.env
RUN chmod 0755 /app/test/test_cleanup
