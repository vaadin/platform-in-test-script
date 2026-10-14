## LIBRARY for patching Vaadin starters or demos specifically for the 25.4 series
##   Loaded and dispatched from lib-patch.sh (applyPatches) for versions matching 25.4.*
##   Follows the same convention as lib-patch-v25.3.sh (applyv253patches)

## Apply 25.4-series specific patches
## $1 application/starter name
## $2 type (current | next)
## $3 version (e.g. 25.4.0-alpha3)
applyv254patches() {
  local app_=$1 type_=$2 vers_=$3
  case $app_ in
    ## ai-integrations-demo) (Not needed since vaadin/ai-integrations-demo#39)
      ## The demo's TestUi mocked VaadinService without stubbing getEventBus(),
      ## which Flow 25.4 calls when it reports data provider queries (vaadin/flow#25963).
      ## The demo now stubs it itself.
      ##;;
  esac
  return 0
}
