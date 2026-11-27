## LIBRARY for patching Vaadin starters or demos specifically for the 25.4 series
##   Loaded and dispatched from lib-patch.sh (applyPatches) for versions matching 25.4.*
##   Follows the same convention as lib-patch-v25.3.sh (applyv253patches)

## Spring Boot version that Vaadin 25.4 is built and tested against.
## TODO: update to the GA version once Spring Boot 4.2.0 is released
SPRING_BOOT_V254=4.2.0-RC2

## Apply 25.4-series specific patches
## $1 application/starter name
## $2 type (current | next)
## $3 version (e.g. 25.4.0-alpha3)
applyv254patches() {
  local app_=$1 type_=$2 vers_=$3

  ## Vaadin 25.4 moves to Spring Boot 4.2, projects still on 4.0/4.1 need to be bumped
  updateSpringBootV254
  ## AI integrations classes were renamed in 25.4 (AI/LLM -> Ai/Llm, DatabaseProvider -> QueryExecutor)
  renameAiIntegrationsClassesV254
  ## browserless-test renamed ExecutedJavaScript.getAll() to getExecutions()
  renameExecutedJavaScriptGetAllV254

  case $app_ in
    ## ai-integrations-demo) (Not needed since vaadin/ai-integrations-demo#39)
      ## The demo's TestUi mocked VaadinService without stubbing getEventBus(),
      ## which Flow 25.4 calls when it reports data provider queries (vaadin/flow#25963).
      ## The demo now stubs it itself.
      ##;;
  esac
  return 0
}

## Rename the AI integrations types to their 25.4 names in projects that use them
## (e.g. ai-integrations-demo, expo-flow, manolo/vaadin-showcase)
##   - AI/LLM in type names became Ai/Llm, e.g. AIOrchestrator -> AiOrchestrator,
##     LLMProvider -> LlmProvider, SpringAILLMProvider -> SpringAiLlmProvider
##     (vaadin/flow-components#10832, CP #10834)
##   - DatabaseProvider -> QueryExecutor, DatabaseProviderAITools -> QueryExecutorAiTools
##     (vaadin/flow-components#10837, CP #10840)
## Not covered: removed API, such as setMaxCallsPerTool() or ToolCallLimitExceededException (#10839)
renameAiIntegrationsClassesV254() {
  local _files _f
  _files=`grep -rlE 'com\.vaadin\.flow\.component\.ai\.' . --include='*.java' --include='*.kt' 2>/dev/null | grep -v '/target/\|/node_modules/'`
  [ -z "$_files" ] && return 0
  for _f in $_files; do
    [ -z "$TEST" ] && warn "renaming AI integrations classes for 25.4 in $_f" || cmd "## renaming AI integrations classes for 25.4 in $_f"
    perl -pi -e '
      s/\bDatabaseProviderAITools\b/QueryExecutorAiTools/g;
      s/\bDatabaseProviderAiTools\b/QueryExecutorAiTools/g;
      s/\bDatabaseProvider\b/QueryExecutor/g;
      s/\bLangChain4JLLMProvider\b/LangChain4jLlmProvider/g;
      s/\bSpringAILLMProvider\b/SpringAiLlmProvider/g;
      s/\bLLM(Provider|ProviderHelpers|Request)\b/Llm$1/g;
      s/\bAI(Attachment|Controller|DataRow|FileReceiver|Input|Message|MessageList|Orchestrator|TurnEvents|ExtensionsLicense|ComponentsFeatureFlagProvider|ComponentsExperimentalFeatureException)\b/Ai$1/g;
      s/\b(Chart|Form|Grid)AI(Controller|Tools)\b/$1Ai$2/g;
    ' "$_f"
  done
  return 0
}

## Rename ExecutedJavaScript.getAll(...) to getExecutions(...) (vaadin/browserless-test#393)
## Only files that use ExecutedJavaScript are touched, e.g. use-cases signals MainLayoutTest
renameExecutedJavaScriptGetAllV254() {
  local _files _f
  _files=`grep -rl 'ExecutedJavaScript' . --include='*.java' --include='*.kt' 2>/dev/null | grep -v '/target/\|/node_modules/'`
  [ -z "$_files" ] && return 0
  for _f in $_files; do
    [ -z "$TEST" ] && warn "renaming ExecutedJavaScript.getAll() to getExecutions() in $_f" || cmd "## renaming ExecutedJavaScript.getAll() to getExecutions() in $_f"
    perl -pi -e 's/\.getAll\(/.getExecutions(/g' "$_f"
  done
  return 0
}

## Bump Spring Boot (Maven parent and Gradle plugin) to $SPRING_BOOT_V254
## Only projects on Spring Boot 4.0.x or 4.1.x are touched, so that projects already
## on 4.2+ (e.g. 4.2.0 GA, which sorts lower than the RC) are never downgraded.
updateSpringBootV254() {
  local _f _boot_ _upd_
  for _f in `getPomFiles`; do
    _boot_=`perl -0777 -ne 'print $1 if m|<parent>.*?<artifactId>spring-boot-starter-parent</artifactId>\s*<version>([^<]+)</version>|s' "$_f"`
    case "$_boot_" in 4.0.*|4.1.*) _upd_=1 ;; esac
  done
  [ -n "$_upd_" ] && changeMavenBlock parent org.springframework.boot spring-boot-starter-parent $SPRING_BOOT_V254

  if [ -f build.gradle ]; then
    _boot_=`perl -ne 'print $1 if m|id\s*["\x27]org\.springframework\.boot["\x27]\s*version\s*["\x27]([^"\x27]+)|' build.gradle`
    case "$_boot_" in 4.0.*|4.1.*) setVersionInGradle "org.springframework.boot" $SPRING_BOOT_V254 ;; esac
  fi
  return 0
}
