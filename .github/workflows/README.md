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


### Variables

#### GHA_FFRN_BUILD_SIGN_ENABLED

Set to 1 to enable signing of manifests. Default is to skip signing so that it won't cause problems in forks.

#### GHA_FFRN_BUILD_DEPLOY_ENABLED

Set to 1 to enable deployment of firmware. Default is to skip deployment so that it won't cause problems in forks.