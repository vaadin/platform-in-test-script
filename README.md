# [Platform-In-Test Script]

# How To Use

```
./scripts/pit/run.sh --help
```

```
Use: ./scripts/pit/run.sh [version=] [starters=] [port=] [timeout=] [verbose] [offline] [interactive] [skiptests] [pnpm] [vite] [help]

  version      Vaadin version to test, by default current stable, otherwise it runs tests against current stable and then against given version.
  starters     List of demos o presets separated by comma to run (default: all) valid options:
                 latest-java
                 latest-java-top
                 latest-javahtml
                 latest-typescript
                 latest-typescript-top
                 latest-java_partial-auth
                 latest-typescript_partial-auth
                 skeleton-starter-flow-cdi
                 base-starter-spring-gradle
                 base-starter-flow-quarkus
                 skeleton-starter-flow-spring
                 vaadin-flow-karaf-example
                 base-starter-flow-osgi
  port         HTTP Port for thee servlet container (default: 8080)
  timeout      Time in secs to wait for server to start (default 300)
  verbose      Show server output (default silent)
  offline      Do not remove previous folders, and do not use network for mvn (default online)
  interactive  Play Bell and ask user to manually test the application (default non interactive)
  skiptests    Skip Selenium IDE Tests (default run tests). Note: selenium-ide does not work in gitpod
  pnpm         Use pnpm instead of npm to speed up frontend compilation (default npm)
  vite         Use vite inetad of webpack to speed up frontend compilation (default webpack)
  help         Show this message
```


