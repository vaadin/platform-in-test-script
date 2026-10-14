## LIBRARY for patching Vaadin starters or demos specifically for the 25.4 series
##   Loaded and dispatched from lib-patch.sh (applyPatches) for versions matching 25.4.*
##   Follows the same convention as lib-patch-v25.3.sh (applyv253patches)

## Apply 25.4-series specific patches
## $1 application/starter name
## $2 type (current | next)
## $3 version (e.g. 25.4.0-alpha3)
applyv254patches() {
  local app_=$1 type_=$2 vers_=$3 F
  case $app_ in
    ai-integrations-demo)
      ## Flow 25.4 reports data provider queries on the service event bus
      ## (vaadin/flow#25262), so a grid counting its rows calls
      ## VaadinService.getEventBus(). The demo's TestUi mocks VaadinService with
      ## Mockito, whose getEventBus() returns null, and 7 tests in ClaimsViewTest
      ## fail with a NullPointerException in DataFetchObserver. Stub the event bus
      ## as a real service has one. Skipped once the demo stubs it itself.
      ## Not needed once Flow checks for a missing event bus: vaadin/flow#26417
      F=src/test/java/com/vaadin/demo/nordicsupply/ui/TestUi.java
      if [ -f "$F" ] && ! grep -q 'getEventBus' "$F"; then
        warn "Stubbing VaadinService.getEventBus() in $F"
        perl -pi -e 's|^(import com\.vaadin\.flow\.server\.VaadinService;)(\r?\n)|$1$2import com.vaadin.flow.server.VaadinServiceEventBus;$2|' "$F"
        perl -pi -e 's|^(\s*)(when\(service\.getContext\(\)\)\.thenReturn\(context\);)(\r?\n)|$1$2$3$1when(service.getEventBus()).thenReturn(new VaadinServiceEventBus(service));$3|' "$F"
      fi
      ;;
  esac
  return 0
}
