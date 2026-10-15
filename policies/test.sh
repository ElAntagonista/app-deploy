#!/usr/bin/env bash
# Policy tests: known-bad fixtures must be blocked by the gates, on the
# expected checks. cnspec also exits non-zero on errors, so the exit code
# alone can't tell "blocked" from "broken"; each case asserts check results.
#
# Usage: policies/test.sh <directory with Mondoo policy bundles>
set -euo pipefail

vendor="${1:?usage: policies/test.sh <mondoo-policies-dir>}"
cd "$(dirname "$0")/.."
failed=0

# expect_blocked <name> "<check uids that must fail>" <cnspec scan args...>
expect_blocked() {
  local name=$1 expected=$2 out ok=1 uid status
  shift 2
  out="$(mktemp)"
  if cnspec scan "$@" --incognito --risk-threshold 80 -o json >"$out" 2>/dev/null; then
    echo "FAIL $name: the gate passed, expected it to block"
    failed=1
    return
  fi
  for uid in $expected; do
    status=$(jq -r --arg uid "$uid" \
      '[.scores[].values | to_entries[] | select(.key | endswith("/queries/" + $uid)) | .value.status] | first // "missing"' \
      "$out")
    if [[ "$status" != "fail" ]]; then
      echo "FAIL $name: $uid is '$status', expected 'fail'"
      ok=0
      failed=1
    fi
  done
  [[ $ok -eq 1 ]] && echo "ok   $name"
}

expect_blocked "Dockerfile gate blocks a bad Dockerfile" \
  "app-dockerfile-binary-path app-dockerfile-expose-8080 mondoo-docker-security-non-root-user" \
  docker file policies/testdata/Dockerfile \
  -f "$vendor/mondoo-dockerfile-security.mql.yaml" \
  -f policies/dockerfile.mql.yaml --policy app-gate-dockerfile

expect_blocked "Kubernetes gate blocks a bad Deployment" \
  "app-k8s-image-pinned app-k8s-readiness mondoo-kubernetes-security-deployment-privilegedcontainer mondoo-kubernetes-security-deployment-runasnonroot" \
  k8s policies/testdata/deployment.yaml --discover deployments \
  -f "$vendor/mondoo-kubernetes-security.mql.yaml" \
  -f policies/k8s.mql.yaml --policy app-gate-k8s

exit "$failed"
