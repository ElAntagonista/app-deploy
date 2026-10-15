# Known-bad fixture for policies/test.sh: wrong binary path, no EXPOSE,
# runs as root. The Dockerfile gate must block it.
FROM gcr.io/distroless/static-debian13@sha256:e2e927ec666bae08560abb3c55d0659eceabb657f56b6782ab500a9fc7f555e3
COPY app /app
USER root
ENTRYPOINT ["/app"]
