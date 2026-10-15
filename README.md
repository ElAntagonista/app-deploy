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

### Registry: GHCR

Images are published to `ghcr.io/elantagonista/app-go`. Alternatives considered:
Docker Hub, a cloud registry (ECR, Artifact Registry, ACR) and a self-hosted
one (Harbor).

- **No registry credential to manage.** The workflow pushes with its built-in
  `GITHUB_TOKEN` (`packages: write`), which is short-lived and scoped to one
  job. Docker Hub would need a long-lived access token stored as a secret,
  with rotation and leak risk.
- **One platform for code and artifacts.** Identity, permissions and audit log
  are GitHub's. The package is linked to this repo, so who can publish an
  image follows who can change this repo.
- **No anonymous pull rate limits** for public images, unlike Docker Hub, so
  cluster nodes can pull freely.
- **OCI-native.** Multi-arch indexes, attestations, SBOMs and cosign
  signatures are stored next to the image, ready for supply-chain hardening.
- **A cloud registry is the better choice when the cluster runs in that
  cloud** (IAM-based pulls, private networking, built-in scanning).

### Image build workflow

`.github/workflows/build-image.yml` packages a given app-go release.

- **Checksum-verified inputs.** It downloads the release's Linux binaries and
  verifies them against the release's `checksums.txt` before building, so the
  image can only contain the bytes that were released.
- **Injection-safe version handling.** The version must match strict semver
  and only reaches shell steps as an environment variable, never as
  `${{ … }}` pasted into a script. This matters once the version arrives in a
  cross-repo dispatch payload.
- **No QEMU.** The Dockerfile has no `RUN`, so buildx assembles the arm64 image
  without executing anything and emulation is not needed.
- **No `latest` tag.** Rebuilding an older version would move `latest`
  backwards. Images are tagged with the exact release version, and the
  deployment pins it.
- **Two triggers, one code path.** app-go fires `repository_dispatch`
  (`new-release`, payload `{"version": "v1.2.3"}`) after each release;
  `workflow_dispatch` is the manual fallback for rebuilds and backfills. Both
  resolve to the same `VERSION`, and each run is titled with the version it
  builds.

### Kubernetes: Kustomize

`k8s/` deploys the app with one command:

```sh
kubectl apply -k k8s/
```

- **Plain YAML, no templating language.** The manifests are reviewable as
  written, and `kubectl kustomize k8s/` shows exactly what will be applied.
- **Declarative version pinning.** A release changes one line (`newTag` in
  `kustomization.yaml`), which automation can bump with
  `kustomize edit set image`.
- **GitOps-ready.** Flux and Argo CD consume the folder natively, so adopting
  either needs no rewrite.
- **Scales by composition.** Overlays (for example `overlays/prod`) can patch
  this base when more environments appear.
- **Helm rejected:** templates, values and chart packaging pay off when a
  configurable app is distributed to many consumers; for one Deployment and
  one Service they are indirection. **Raw YAML rejected:** version pins and
  per-environment differences would turn into `sed` and copy-paste.
- **Validated in CI** (`.github/workflows/ci.yml`) on every push and pull
  request: the manifests must render with Kustomize, and the rendered output
  must pass a strict schema check (kubeconform, Kubernetes 1.37), which
  rejects unknown or misspelled fields before anything reaches a cluster.
