# Development Guide

## Go Driver Development

### Prerequisites

- Go 1.24+
- Access to a Rancher v2.11.x instance for testing

### Building

```bash
cd driver/

# Build for local testing (macOS)
make build

# Build Linux binary for Rancher
make build-linux

# Or manually:
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
  -ldflags "-X main.version=$(git describe --tags --always)" \
  -o docker-machine-driver-hetzner \
  ./cmd/docker-machine-driver-hetzner
```

### Testing Locally

You can test the driver binary directly:

```bash
./docker-machine-driver-hetzner --version
```

### Running Tests

```bash
cd driver/
make test
```

Tests mock the Hetzner API at the HTTP level using `httptest.NewServer`. See [Contributing](contributing.md#testing-notes) for details on writing tests.

### Releasing

Releases are fully automated — pushing to any tracked branch triggers a build and publish. See the [Releasing](releasing.md) page for the full version scheme, what gets published, and how to test dev builds.

## UI Extension Development

### Prerequisites

- Node.js 18+ (tested with v23.7)
- Yarn 1.x

### Setup

```bash
cd extension/
yarn install
```

### Development Server

```bash
API=https://your-rancher-url yarn dev
```

Opens at `https://localhost:8005/`. Log in with your Rancher credentials.
Changes to Vue components hot-reload automatically. Changes to `index.js`
(store registration) require a server restart.

### Key Conventions

**Component filenames must match driver name:**
- `cloud-credential/hetzner.vue` (not `Hetzner.vue` or `hetzner-cloud.vue`)
- `machine-config/hetzner.vue`

**Store module must be registered explicitly** in `index.js` via
`plugin.addStore('hetzner', ...)`. It is NOT auto-discovered.

**API proxy auth header format:**
```
x-api-cattleauth-header: Bearer credID={id} passwordField=apiToken
```
The `passwordField` value must match the credential field name exactly.

### Building for Production

```bash
cd extension/
yarn build-pkg hetzner-node-driver
```

Output is in `dist-pkg/`. This can be served as a Rancher UIPlugin.

!!! note
    In CI, the build uses `yarn publish-pkgs` instead of `yarn build-pkg`. This builds the extension **and** creates the Helm chart and index files for the extension repository. You generally don't need to run this locally — see [Releasing](releasing.md) for how the automated pipeline works.
