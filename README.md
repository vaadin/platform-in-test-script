# [Platform-In-Test Script]

# How To Use

```
./scripts/pit/run.sh --help
```

```
Use: ./scripts/pit/run.sh with the next options:

 --version=string  Vaadin version to test, if not given it only tests current stable, otherwise it runs tests against current stable and then against given version.
 --demos           Run all demo projects
 --generated       Run all generated projects (start and archetypes)
 --port=number     HTTP port for thee servlet container (default: 8080)
 --timeout=number  Time in secs to wait for server to start (default 300)
 --jdk=NN          Use a specific JDK version to run the tests
 --verbose         Show server output (default silent)
 --offline         Do not remove already downloaded projects, and do not use network for mvn (default online)
 --interactive     Play a bell and ask user to manually test the application (default non interactive)
 --skip-tests      Skip UI Tests (default run tests). Note: selenium-ide does not work in gitpod
 --skip-current    Skip running build in current version
 --skip-prod       Skip production validations
 --skip-dev        Skip dev-mode validations
 --skip-clean      Do not clean maven cache
 --skip-helm       Do not re-install control-center with helm and continue running tests, implies (--offline, --keep-cc)
 --skip-setup      Like --skip-helm but also do not run first playwright setup test, implies --skip-build --skip-helm
 --skip-apps       Like --skip-setup but also do not run playwright install apps test, implies --skip-build --skip-setup
 --skip-pw         Do not run playwright tests
 --cluster=name    Run tests in an existing k8s cluster
 --vendor=name     Use a specific cluster vendor to run control-center tests options: [dd, kind, do] (default: kind)
 --keep-cc         Keep control-center running after tests
 --keep-apps       Keep installed apps in control-center, implies --keep-cc
 --proxy-cc        Forward port 443 from k8s cluster to localhost
 --events-cc       Display events from control-center
 --cc-version      Install this version for current
 --skip-build      Skip building the docker images for control-center
 --delete-cluster  Delete the cluster/s
 --dashboard=*     Install kubernetes dashboard, options [install, uninstall] (default: install)
 --pnpm            Use pnpm instead of npm to speed up frontend compilation (default npm)
 --vite            Use vite inetad of webpack to speed up frontend compilation (default webpack)
 --list            Show the list of available starters
 --hub             Use selenium hub instead of local chrome, it assumes that selenium docker is running as service in localhost
 --commit          Commit changes to the base branch
 --test            Checkout starters, and show steps and commands to execute, but don't run them
 --git-ssh         Use git-ssh instead of https to checkout projects (you need a valid ssh key)
 --headless        Run the browser in headless mode even if interactive mode is enabled
 --headed          Run the browser in headed mode even if interactive mode is disabled
 --function        run only one function of the libs in current folder.
                   everything after this argument is the function name and arguments passed to the function.
                   you should take care with arguments that contain spaces, they should be quoted twice.
 --help            Show this message
 --starters=list   List of demos or presets separated by comma to run (default: all) valid options:
                   · latest-java
                   · latest-java-top
                   · latest-java_partial-auth
                   · flow-crm-tutorial
                   · react
                   · react-crm-tutorial
                   · react-tutorial
                   · test-hybrid-react
                   · default
                   · latest-java_partial-auth_partial-prerelease
                   · archetype-hotswap
                   · archetype-jetty
                   · archetype-spring
                   · vaadin-quarkus
                   · hilla-react-cli
                   · initializer-vaadin-maven-react
                   · initializer-vaadin-maven-flow
                   · initializer-vaadin-gradle-react
                   · initializer-vaadin-gradle-flow
                   · collaboration
                   · control-center
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
                   · mpr-demo_jdk17
                   · testbench-demo
                   · ce-demo
                   · start
                   · spring-guides/gs-crud-with-vaadin/complete
                   · spring-petclinic/spring-petclinic-vaadin-flow
                   · form-filler-demo
                   · flow-hilla-hybrid-example
                   · designer-tutorial
                   · walking-skeleton:v24.7-hybrid
                   · releases-graph
                   · expo-flow
```



