FROM debian:trixie-slim

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

# Deliberately no USER: 'cleanup' uses the quota of whoever runs it and needs
#  privilege to remove other users' files, so the uid is a deployment
#  decision.  Set it in the pod spec.
#
# CMD rather than ENTRYPOINT so it stays easy to override (e.g. to run the
#  test suite in the image).
CMD ["/app/cleanup"]
