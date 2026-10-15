# syntax=docker/dockerfile:1

# Packages a released app binary; it never compiles. The build context must
# contain the release assets in dist/ (see README).
FROM gcr.io/distroless/static-debian13:nonroot@sha256:e2e927ec666bae08560abb3c55d0659eceabb657f56b6782ab500a9fc7f555e3

ARG VERSION
ARG TARGETOS
ARG TARGETARCH

COPY --chmod=0755 dist/app_${VERSION}_${TARGETOS}_${TARGETARCH} /usr/local/bin/app

EXPOSE 8080
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/app"]
