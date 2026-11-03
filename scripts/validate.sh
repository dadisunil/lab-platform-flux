#!/usr/bin/env bash
# Validate every manifest in the repo:
#   1. plain YAML files with kubeconform
#   2. every kustomization built with kustomize, then checked with kubeconform
# Flux's own CRD schemas are downloaded once so Flux objects are really validated, not skipped.
set -o errexit -o pipefail -o nounset
 
FLUX_VERSION="v2.10.0"
SCHEMA_DIR="${TMPDIR:-/tmp}/flux-crd-schemas-${FLUX_VERSION}"
 
if [ ! -d "${SCHEMA_DIR}" ]; then
  mkdir -p "${SCHEMA_DIR}"
  curl -fsSL "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/crd-schemas.tar.gz" \
    | tar -xzf - -C "${SCHEMA_DIR}"
fi
 
# The explicit {{ ... }} template matters: a bare directory is silently SKIPPED by kubeconform, so Flux
# objects would be "validated" without ever being checked. The file names look like kustomization-kustomize-v1.json.
KUBECONFORM_FLAGS=(-strict -ignore-missing-schemas -schema-location default \
  -schema-location "${SCHEMA_DIR}/{{ .ResourceKind }}{{ .KindSuffix }}.json" -summary)
 
echo "== 1/2 plain manifests"
find . -type f -name '*.yaml' \
  -not -path './.git/*' -not -path './.github/*' -not -path './kind/*' \
  -not -path '*/flux-system/*' -not -name 'kustomization.yaml' -print0 \
  | xargs -0 -n 20 kubeconform "${KUBECONFORM_FLAGS[@]}"
 
echo "== 2/2 kustomize overlays"
find . -type f -name 'kustomization.yaml' -not -path './.git/*' -not -path '*/flux-system/*' -print0 \
  | while IFS= read -r -d '' file; do
      dir="$(dirname "${file}")"
      echo "-- ${dir}"
      kustomize build "${dir}" | kubeconform "${KUBECONFORM_FLAGS[@]}"
    done
 
echo "validate.sh: all good"

