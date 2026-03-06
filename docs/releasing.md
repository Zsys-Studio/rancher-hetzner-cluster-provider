# Releasing

All releases are fully automated via GitHub Actions. Pushing to any tracked branch triggers the [`release.yml`](https://github.com/zsys-studio/rancher-hetzner-cluster-provider/blob/main/.github/workflows/release.yml) workflow, which builds and publishes both the Go driver and the UI extension with a single shared version.

## Version Scheme

| Branch | Tag / Version | Release type |
|--------|--------------|--------------|
| `main` | `v0.1.0`, `v0.2.0`, ... | Stable — auto-incremented minor version |
| `develop` | `v0.0.0-dev.develop.<sha>` | Pre-release |
| `feature/*` | `v0.0.0-dev.feature-foo.<sha>` | Pre-release |
| `fix/*` | `v0.0.0-dev.fix-bar.<sha>` | Pre-release |

- **Stable releases** (main): the workflow finds the latest stable tag and bumps the minor version. For example, if the latest tag is `v0.8.0`, the next push to main creates `v0.9.0`.
- **Pre-releases** (all other branches): tagged as `v0.0.0-dev.<sanitized-branch>.<7-char-sha>`. Branch names are sanitized (`/` → `-`) for tag compatibility.

The driver binaries and the extension Helm chart always share the same version — there is no separate versioning for the extension.

## What Gets Published

Each release produces:

1. **GitHub Release** with driver binaries (linux amd64 + arm64) built by GoReleaser, plus the extension tarball
2. **Extension Helm chart** published to a dedicated branch that Rancher reads as a chart repository

### Extension Helm Repository Branches

| Branch | Publishes to | Purpose |
|--------|-------------|---------|
| `main` | `rancher-extension` | Stable versions for production |
| All others | `rancher-extension-dev` | Dev versions for testing |

The `rancher-extension` branch is the stable Helm chart repository. The `rancher-extension-dev` branch is a rolling repository that holds up to **10 most recent** dev versions across all branches. Older dev versions are automatically pruned (files and index entries removed).

## Testing Dev Builds in Rancher

To install pre-release extension versions in your Rancher instance, add the dev repository:

### Via Rancher UI

1. Navigate to **Extensions** → click the **kebab menu (⋮)** → **Manage Repositories**
2. Click **Create** and fill in:
    - **Name:** `zsys-rancher-hetzner-dev`
    - **Target:** Git repository
    - **Git Repo URL:** `https://github.com/zsys-studio/rancher-hetzner-cluster-provider`
    - **Git Branch:** `rancher-extension-dev`
3. Click **Create**
4. Go to **Extensions > Available** — dev versions will appear alongside stable ones

### Via kubectl

```bash
kubectl apply -f - <<'EOF'
apiVersion: catalog.cattle.io/v1
kind: ClusterRepo
metadata:
  name: zsys-rancher-hetzner-dev
spec:
  gitRepo: https://github.com/zsys-studio/rancher-hetzner-cluster-provider
  gitBranch: rancher-extension-dev
EOF
```

!!! tip
    You can have both the stable (`rancher-extension`) and dev (`rancher-extension-dev`) repositories added simultaneously. Rancher will show all available versions from both.

### Updating the Driver for Dev Testing

Dev builds also publish driver binaries to the GitHub pre-release. To point your Rancher instance at a dev driver:

```bash
# Replace <TAG> and <VERSION> with the dev version, e.g.:
#   TAG=v0.0.0-dev.develop.a1b2c3d
#   VERSION=0.0.0-dev.develop.a1b2c3d
kubectl patch nodedriver.management.cattle.io/hetzner --type=merge -p \
  '{"spec":{"url":"https://github.com/zsys-studio/rancher-hetzner-cluster-provider/releases/download/<TAG>/docker-machine-driver-hetzner_<VERSION>_linux_amd64.tar.gz"},"status":{"appliedURL":""}}'
```

Clearing `status.appliedURL` forces Rancher to re-download the binary.

### Force-refresh the Extension Repository

If Rancher doesn't pick up a newly published version, force a re-sync:

```bash
kubectl patch clusterrepo zsys-rancher-hetzner-dev --type=merge \
  -p "{\"spec\":{\"forceUpdate\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}"
```

## Workflow Details

### Concurrency

Releases use the concurrency group `release-<branch>`. This means:

- Parallel pushes to **different branches** run simultaneously
- Parallel pushes to the **same branch** are serialized (queued, not cancelled)

### Dev Release Cleanup

Each push to a non-main branch deletes **old GitHub pre-releases** for that same branch (identified by the tag prefix `v0.0.0-dev.<branch>.`). This prevents unbounded accumulation of pre-releases.

On `rancher-extension-dev`, a similar pruning keeps only the **10 most recent** dev chart versions (by creation timestamp), regardless of branch. This provides a rolling window of recent versions for testing while keeping the repository clean.

### Extension Version Injection

The `package.json` in the extension source has `"version": "0.0.0"` as a placeholder. During CI, the workflow injects the computed version before building:

```bash
jq --arg v "$VERSION" '.version = $v' package.json > tmp.json && mv tmp.json package.json
```

This ensures the built Helm chart, JS bundles, and GitHub release all share the exact same version string. Never change the version in `package.json` manually — it is always overridden by CI.
