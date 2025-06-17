
## Usage examples for PiT tests in control-center

##### Run proxy
./scripts/pit/run.sh --proxy

##### Run proxy for a specific cluster
./scripts/pit/run.sh --vendor=kind --cluster=pit --proxy

##### Delete cluster in DO
./scripts/pit/run.sh --proxy --delete --vendor=do

##### Install cluster and helm chart for a specific CC version
./scripts/pit/run.sh --starters=control-center --keep-cc \
  --cc-version=1.3.0-beta2 \
  --skip-pw

##### Compile apps and CC for a specific platform version, and load local images in cluster
./scripts/pit/run.sh --starters=control-center --keep-cc \
  --version=24.8.0.beta2 \
  --skip-current \
  --skip-helm \
  --skip-pw

##### Push local images to docker central (need to be build as above)
CCPUSH=true \
./scripts/pit/run.sh --starters=control-center --keep-cc \
  --version=24.8.0.beta2 \
  --skip-current \
  --skip-build \
  --skip-helm \
  --skip-pw

./scripts/pit/run.sh --function pushLocalToDockerhub next

##### Install test apps and run tests for new version (needs to have everything set as above)
./scripts/pit/run.sh --starters=control-center --keep-cc \
  --version=24.8.0.beta2 \
  --skip-current \
  --skip-build \
  --skip-helm \
  --keep-apps \
  --headed

##### Run browser tests without headed slow-motion
FAST=true \
./scripts/pit/run.sh --starters=control-center --keep-cc \
  --version=24.8.0.beta2 \
  --skip-current \
  --skip-build \
  --skip-helm \
  --keep-apps \
  --headed  

##### Remove tests apps from CC
CC_TESTS=cc-remove-apps.js \
./scripts/pit/run.sh --starters=control-center --keep-cc \
  --offline \
  --skip-setup \
  --headed

##### Create a cluster in DO with latest version of CC, compile apps and deploy then
FAST=true ./scripts/pit/run.sh \
   --starters=control-center --keep-cc --version=24.8.0.beta2 --headed --skip-current --vendor=do








