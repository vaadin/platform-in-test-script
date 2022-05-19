#!/bin/sh
. `dirname $0`/lib/lib-args.sh
. `dirname $0`/lib/lib-start.sh
. `dirname $0`/lib/lib-demos.sh

trap "doExit" INT TERM EXIT

DEFAULT_PORT=8080
DEFAULT_TIMEOUT=300
PRESETS="
latest-java
latest-java-top
latest-javahtml
latest-typescript
latest-typescript-top
latest-java_partial-auth
latest-typescript_partial-auth"
DEMOS="
skeleton-starter-flow-cdi
base-starter-spring-gradle
base-starter-flow-quarkus
skeleton-starter-flow-spring
vaadin-flow-karaf-example
base-starter-flow-osgi"
DEFAULT_STARTERS=`echo "$PRESETS$DEMOS" | tr "\n" ","`

### MAIN
main() {
  presets=""; demos=""
  for i in `echo "$STARTERS" | tr ',' ' '`
  do
    if echo "$PRESETS" | grep -q "^$i$"; then
      presets="$presets $i"
    elif echo "$DEMOS" | grep -q "^$i$"; then
      demos="$demos $i"
    else
      log "Unknown starter: $i"
    fi
  done

  checkBusyPort "$PORT" || exit 1

  runStarters "$presets" "$PORT" "$VERSION" "$OFFLINE" || exit 1
  runDemos "$demos" "$PORT" "$VERSION" "$OFFLINE" || exit 1
}

checkArgs ${@}
main

