FROM alpine:latest

RUN apk add quota-tools grep
COPY cleanup /cleanup
RUN chmod 0755 /cleanup
# Uncomment these if you want to do in-container testing.
# COPY test_cleanup test.env /
# RUN chmod 0755 /test_cleanup
