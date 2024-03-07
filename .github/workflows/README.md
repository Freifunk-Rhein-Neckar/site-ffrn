# Workflows

## build

Build and release Firmware.

### Secrets

#### GHA_FFRN_BUILD_DEPLOY_SSH_KEY

SSH private key required for deployment on the firmware download server.

#### GHA_FFRN_BUILD_ECDSA_KEY_{branch}

Private ECDSA key for signing the manifest for a given `branch`.

## check-build-info

Validate the `build-info.json` is valid JSON.
