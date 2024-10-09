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
                   · latest-lit
                   · latest-lit-top
                   · latest-java_partial-auth
                   · latest-lit_partial-auth
                   · flow-crm-tutorial
                   · react
                   · react-crm-tutorial
                   · react-tutorial
                   · test-hybrid
                   · test-hybrid-react
                   · default
                   · latest-lit_partial-nextprerelease
                   · latest-lit_partial-prerelease
                   · latest-java_partial-auth_partial-prerelease
                   · archetype-hotswap
                   · archetype-jetty
                   · archetype-spring
                   · vaadin-quarkus
                   · hilla-react-cli
                   · skeleton-starter-flow
                   · skeleton-starter-flow-spring
                   · skeleton-starter-hilla-react
                   · skeleton-starter-hilla-react-gradle
                   · skeleton-starter-flow-cdi
                   · skeleton-starter-hilla-lit
                   · skeleton-starter-hilla-lit-gradle
                   · skeleton-starter-kotlin-spring
                   · business-app-starter-flow
                   · base-starter-spring-gradle
                   · base-starter-flow-quarkus
                   · base-starter-gradle
                   · flow-crm-tutorial
                   · hilla-crm-tutorial
                   · hilla-quickstart-tutorial
                   · hilla-basics-tutorial
                   · flow-quickstart-tutorial
                   · addon-template
                   · addon-starter-flow
                   · npm-addon-template
                   · client-server-addon-template
                   · spreadsheet-demo
                   · vaadin-form-example
                   · vaadin-rest-example
                   · vaadin-localization-example
                   · vaadin-database-example
                   · layout-examples
                   · flow-spring-examples
                   · vaadin-oauth-example
                   · multi-module-example
                   · bookstore-example
                   · bookstore-example:rtl-demo
                   · bakery-app-starter-flow-spring
                   · k8s-demo-app
                   · mpr-demo
                   · testbench-demo
                   · ce-demo
                   · start
                   · spring-guides/gs-crud-with-vaadin/complete
                   · spring-petclinic/spring-petclinic-vaadin-flow
                   · form-filler-demo
                   · flow-hilla-hybrid-example
                   · designer-tutorial
                   ·
 --demos           Run all demo projects
 --generated       Run all generated projects (start and archetypes)
 --port=number     HTTP port for thee servlet container (default: 8080)
 --timeout=number  Time in secs to wait for server to start (default 300)
 --verbose         Show server output (default silent)
 --offline         Do not remove already downloaded projects, and do not use network for mvn (default online)
 --interactive     Play a bell and ask user to manually test the application (default non interactive)
 --skip-tests      Skip UI Tests (default run tests). Note: selenium-ide does not work in gitpod
 --skip-current    Skip running build in current version
 --skip-prod       Skip production validations
 --skip-dev        Skip dev-mode validations
 --pnpm            Use pnpm instead of npm to speed up frontend compilation (default npm)
 --vite            Use vite inetad of webpack to speed up frontend compilation (default webpack)
 --list            Show the list of available starters
 --hub             Use selenium hub instead of local chrome, it assumes that selenium docker is running as service in localhost
 --help            Show this message
 --commit          Commit changes to the base branch
 --test            Checkout starters, and show steps and commands to execute, but don't run them
 --skip-clean      Do not clean maven cache
 --function        run only one function of the libs in current folder.
                   everything after this argument is the function name and arguments passed to the function.
                   you should take care with arguments that contain spaces, they should be quoted twice.
```


