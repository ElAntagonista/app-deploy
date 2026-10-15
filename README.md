# app-deploy

Containerizes and deploys `app` from
[app-go](https://github.com/ElAntagonista/app-go).

## Build the image locally

```sh
V=v0.1.0
gh release download "$V" -R ElAntagonista/app-go -D dist \
  -p "app_${V}_linux_*" -p checksums.txt
(cd dist && shasum -a 256 -c --ignore-missing checksums.txt)
docker buildx build --platform linux/amd64,linux/arm64 \
  --build-arg VERSION="$V" -t app:"$V" .
```

## Decisions log

### Image

- **Build once, promote.** The Dockerfile copies the binary from an app-go
  GitHub Release; it never compiles. The image runs the exact binary that was
  tested and released.
- **Base: distroless/static (Debian 13), nonroot, pinned by digest.** No shell
  or package manager, a ~4 MB image and a minimal CVE surface. The digest pin
  makes builds reproducible.
- **Numeric user `65532`.** Kubernetes `runAsNonRoot` can only verify a numeric
  UID; `USER nonroot` would be refused at pod start.
- **Whitelisted build context.** `.dockerignore` admits only `dist/app_*`.
- **Multi-arch from one Dockerfile.** `TARGETOS`/`TARGETARCH` pick the matching
  release asset per platform.
