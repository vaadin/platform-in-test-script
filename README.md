# [Platform-In-Test Script]

# How To Use

```
./scripts/pit/run.sh --help
```

```
Use: ./scripts/pit/run.sh [version=] [starters=] [port=] [timeout=] [verbose] [offline] [interactive] [skiptests] [pnpm] [vite] [help]

 --version=string  Vaadin version to test, if not given it only tests current stable, otherwise it runs tests against current stable and then against given version.
 --starters=list   List of demos or presets separated by comma to run (default: all) valid options:
                   · latest-java
                   · latest-java-top
                   · latest-javahtml
                   · latest-typescript
                   · latest-typescript-top
                   · latest-java_partial-auth
                   · latest-typescript_partial-auth
                   · skeleton-starter-flow-spring
                   · bakery-app-starter-flow-spring
                   · skeleton-starter-flow-cdi
                   · base-starter-spring-gradle
                   · base-starter-flow-quarkus
                   · vaadin-flow-karaf-example
                   · base-starter-flow-osgi
 --port=number     HTTP port for thee servlet container (default: 8080)
 --timeout=number  Time in secs to wait for server to start (default 300)
 --verbose         Show server output (default silent)
 --offline         Do not remove already downloaded projects, and do not use network for mvn (default online)
 --interactive     Play a bell and ask user to manually test the application (default non interactive)
 --skiptests       Skip UI Tests (default run tests). Note: selenium-ide does not work in gitpod
 --skipcurrent     Skip running build in current version
 --pnpm            Use pnpm instead of npm to speed up frontend compilation (default npm)
 --vite            Use vite inetad of webpack to speed up frontend compilation (default webpack)
 --list            Show the list of available starters
 --help            Show this message
```


