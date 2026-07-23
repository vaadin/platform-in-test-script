## LIBRARY for patching Vaadin starters or demos specifically for the 25.3 series
##   Loaded and dispatched from lib-patch.sh (applyPatches) for versions matching 25.3.*
##   Follows the same convention as lib-patch-v25.sh (applyv25patches)

## Apply 25.3-series specific patches
## $1 application/starter name
## $2 type (current | next)
## $3 version (e.g. 25.3.0-alpha6)
applyv253patches() {
  local app_=$1 type_=$2 vers_=$3
  case $app_ in
    vaadin-quarkus)
      ## The Quarkus vaadin-flow-codestart hardcodes the vaadin-quarkus-extension
      ## version (the latest released, e.g. 25.2.3) instead of tracking ${vaadin.version}.
      ## After bumping vaadin.version the extension is left behind, dragging in an
      ## inconsistent @vaadin/* component set that breaks the frontend build.
      ## Align it with the property so the version bump takes effect. See vaadin/quarkus#316.
      perl -0777 -pi -e 's|(<artifactId>vaadin-quarkus-extension</artifactId>\s*<version>)[^<]+(</version>)|${1}\${vaadin.version}${2}|s' pom.xml
      ;;
  esac
  return 0
}
