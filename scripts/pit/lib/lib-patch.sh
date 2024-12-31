## LIBRARY for patching Vaadin starters or demos
##   It has especial workarounds for specific apps.
##   There could be especial patches for specific versions of Apps, Vaadin or Hilla
##   Patches for special versions are maintained in separated files like lib-patch-v24.sh, lib-patch-v24.4.sh
##   These especial patches are loaded and applied in this script

## Run after updating Vaadin/Hilla versions in order to patch sources
applyPatches() {
  app_=$1; type_=$2; vers_=$3; mod_=$4
  [ -n "$TEST" ] || log "Applying Patches for $app_ $type_ $vers_"

  case $vers_ in
    *alpha*|*beta*|*rc*|*SNAP*) addPrereleases;;
  esac
  expr "$vers_" : ".*SNAPSHOT" >/dev/null && enableSnapshots
  expr "$vers_" : "24.3.0.alpha.*" >/dev/null && addSpringReleaseRepo
  expr "$vers_" : "24.7.*" >/dev/null && patchReactRouterDom && patchFutureRouter
  checkProjectUsingOldVaadin "$type_" "$vers_"
  downgradeJava

  case $app_ in
    archetype-hotswap)
      ## need to happen in patch phase not in the run phase
      enableJBRAutoreload ;;
    vaadin-oauth-example)
      setPropertyInFile src/main/resources/application.properties \
        spring.security.oauth2.client.registration.google.client-id \
        553339476434-a7kb9vna7limjgucee2n0io775ra5qet.apps.googleusercontent.com
      setPropertyInFile src/main/resources/application.properties \
        spring.security.oauth2.client.registration.google.client-secret \
        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
      ;;
    mpr-demo)
      SS=~/vaadin.spreadsheet.developer.license
      [ ! -f $SS ] && err "Install a Valid License $SS" && return 1
      ;;
    form-filler-demo)
      [ -n "$TEST" ] && ([ -z "$OPENAI_TOKEN" ] && cmd "export OPENAI_TOKEN=your_AI_token") && return 0
      [ -z "$OPENAI_TOKEN" ] && err "Set correctly the OPENAI_TOKEN env var" && return 1
      ;;
    vaadin-quarkus)
      log "Fixing quarkus dependencyManagement https://vaadin.com/docs/latest/flow/integrations/quarkus#quarkus.vaadin.knownissues"
      moveQuarkusBomToBottom
      ;;
    designer-tutorial)
      patchFlowPools ;;
  esac

  # always successful
  return 0
}

## REPORTED in: https://github.com/vaadin/hilla/issues/3082
patchReactRouterDom() {
  F=src/main/frontend
  [ ! -d "$F" ] && return
  find $F '(' -name '*.ts' -o -name '*.tsx' ')' -exec perl -pi -e "s| +from +.react-router-dom.| from 'react-router'|g" '{}' ';'
  git diff --quiet -- "$F" || warn "Patched $F because it has 'from 'react-router-dom' occurrences"
}

## TODO: report this in https://github.com/vaadin/flow-hilla-hybrid-example/blob/v24/src/main/frontend/index.tsx#L13
patchFutureRouter() {
  if [ -f src/main/frontend/index.ts* ] && grep -q "RouterProvider" src/main/frontend/index.ts*; then
    warn "Patching src/main/frontend/index.ts* because it has 'RouterProvider'"
    perl -pi -e "s|(<RouterProvider.*)future=.*?( */>)|\$1\$2|g" src/main/frontend/index.ts*
  fi
}

## We use this function to check if the project in its reporitory has not been updated to latest stable vaadin version
checkProjectUsingOldVaadin() {
  [ "$1" != 'current' ] && return
  case $vers_ in
    24.7.*|24.6.*|current) : ;;
    *) reportError "Using old version $vers_" "Please upgrade $app_ to latest stable" ;;
  esac
}

## Run at the beginning of Validate in order to skip upsupported app/version combination
isUnsupported() {
  app_=$1; mod_=$2; vers_=$3;

  ## Karaf and OSGi unsupported in 24.x
  [ $app_ = vaadin-flow-karaf-example -o $app_ = base-starter-flow-osgi ] && return 0

  ## Everything else is supported
  return 1
}

## The minimum version of Java supported by vaadin is 17, hence we test for it
downgradeJava() {
  [ ! -f pom.xml ] && return
  grep -q '<java.version>21</java.version>' pom.xml || return
  cmd "perl -pi -e 's|<java.version>21</java.version>|<java.version>17</java.version>|' pom.xml"
  perl -pi -e 's|<java.version>21</java.version>|<java.version>17</java.version>|' pom.xml
  warn "Downgraded Java version from 21 to 17 in pom.xml"
}

## Moves quarkus dependency to the bottom of the dependencyManagement block
moveQuarkusBomToBottom() {
  changeBlock  \
    '<dependencyManagement>\s*<dependencies>)(\s*<dependency>\s*<groupId>\${quarkus\.platform\.group-id}.*?</dependency>' \
    '\s*</dependencies>\s*</dependencyManagement>' \
    '${1}${3}${2}${4}' pom.xml
}

# removeDeprecated() {
#   [ ! -f pom.xml ] && return
#   grep -q '<productionMode>true</productionMode>' pom.xml || return
#   cmd "perl -0777 -pi -e 's|\s*<productionMode>true</productionMode>\s*||' pom.xml"
#   perl -pi -e 's|\s*<productionMode>true</productionMode>\s*||' pom.xml
#   warn "Removed deprecated productionMode from pom.xml"
# }

## FIXED - k8s-demo-app 23.3.0.alpha2
# patchOldSpringProjects() {
#   changeMavenBlock parent org.springframework.boot spring-boot-starter-parent 2.7.4
# }

## FIXED - bakery 23.1
# patchRouterLink() {
#   find src -name "*.java" | xargs perl -pi -e 's/RouterLink\(null, /RouterLink("", /g'
#   H=`git status --porcelain src`
#   if [ -n "$H" ]; then
#     log "patched RouterLink occurrences in files: $F"
#   fi
# }

## FIXED - Karaf 23.2.2
# patchKarafLicenseOsgi() {
#   __pom=main-ui/pom.xml
#   [ -f $__pom ] && warn "Patching $__pom (adding license-checker 1.10.0)" && perl -pi -e \
#     's,</dependencies>,<dependency><groupId>com.vaadin</groupId><artifactId>license-checker</artifactId><version>1.10.0</version></dependency></dependencies>,' \
#     $__pom
# }

## FIXED - skeleton-starter-flow-spring 23.3.0.alpha2
# patchIndexTs() {
#   __file="frontend/index.ts"
#   if test -f "$__file" && grep -q 'vaadin/flow-frontend' $__file; then
#     warn "patch 23.3.0.alpha2 - Patching $__file because it has vaadin/flow-frontend/ occurrences"
#     perl -pi -e 's,\@vaadin/flow-frontend/,Frontend/generated/jar-resources/,g' $__file
#   fi
# }

## FIXED - latest-typescript*, vaadin-flow-karaf-example, base-starter-flow-quarkus, base-starter-flow-osgi, 23.3.0.alpha3
# patchTsConfig() {
#   H=`ls -1 tsconfig.json */tsconfig.json 2>/dev/null`
#   [ -n "$H" ] && warn "patch 23.3.0.alpha3 - Removing $H" && rm -f tsconfig.json */tsconfig.json
# }

## FIXED - ce does not need any license since 24.5
# installCeLicense() {
#   LIC=ce-license.json
#   [ -n "$TEST" ] && ([ -z "$CE_LICENSE" ] && cmd "## Put a valid CE License in ./$LIC" || cmd "## Copy your CE License to ./$LIC") && return 0
#   [ -z "$CE_LICENSE" ] && err "No \$CE_LICENSE provided" && [ -z "$TEST" ] && return 1
#   warn "Creating license file ./$LIC with the \$CE_LICENSE content"
#   cmd "echo \"\$CE_LICENSE\" > $LIC"
#   echo "$CE_LICENSE" > $LIC
# }

patchFlowPools() {
warn "Patching DevModeHandlerManagerImpl and DevModeInitializer.java in designer-tutorial"
mkdir -p src/main/java/com/vaadin/base/devserver/
cat << EOF > src/main/java/com/vaadin/base/devserver/DevModeHandlerManagerImpl.java
/*
* Copyright 2000-2024 Vaadin Ltd.
*
* Licensed under the Apache License, Version 2.0 (the "License"); you may not
* use this file except in compliance with the License. You may obtain a copy of
* the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
* WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
* License for the specific language governing permissions and limitations under
* the License.
*/
package com.vaadin.base.devserver;

import jakarta.servlet.annotation.HandlesTypes;

import java.io.Closeable;
import java.io.File;
import java.io.Serializable;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicInteger;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vaadin.base.devserver.startup.DevModeInitializer;
import com.vaadin.base.devserver.startup.DevModeStartupListener;
import com.vaadin.flow.internal.DevModeHandler;
import com.vaadin.flow.internal.DevModeHandlerManager;
import com.vaadin.flow.server.Command;
import com.vaadin.flow.server.Mode;
import com.vaadin.flow.server.VaadinContext;
import com.vaadin.flow.server.frontend.FrontendUtils;
import com.vaadin.flow.server.frontend.ThemeUtils;
import com.vaadin.flow.server.startup.ApplicationConfiguration;
import com.vaadin.flow.server.startup.VaadinInitializerException;

/**
* Provides API to access to the {@link DevModeHandler} instance.
* <p>
* For internal use only. May be renamed or removed in a future release.
*
* @author Vaadin Ltd
* @since
*/
public class DevModeHandlerManagerImpl implements DevModeHandlerManager {

    /*
    * Attribute key for storing Dev Mode Handler startup flag.
    *
    * If presented in Servlet Context, shows the Dev Mode Handler already
    * started / become starting. This attribute helps to avoid Dev Mode running
    * twice.
    *
    * Addresses the issue https://github.com/vaadin/spring/issues/502
    */
    private static final class DevModeHandlerAlreadyStartedAttribute
            implements Serializable {
    }

    private DevModeHandler devModeHandler;
    private BrowserLauncher browserLauncher;
    private final Set<Command> shutdownCommands = new HashSet<>();
    private ExecutorService executorService;

    private String applicationUrl;
    private boolean fullyStarted = false;

    @Override
    public Class<?>[] getHandlesTypes() {
        return DevModeStartupListener.class.getAnnotation(HandlesTypes.class)
                .value();
    }

    @Override
    public void setDevModeHandler(DevModeHandler devModeHandler) {
        if (this.devModeHandler != null) {
            throw new IllegalStateException(
                    "Unable to initialize dev mode handler. A handler is already present: "
                            + this.devModeHandler);
        }
        this.devModeHandler = devModeHandler;
    }

    @Override
    public DevModeHandler getDevModeHandler() {
        return devModeHandler;
    }

    @Override
    public void initDevModeHandler(Set<Class<?>> classes, VaadinContext context)
            throws VaadinInitializerException {
        shutdownExecutorService();
        executorService = Executors.newFixedThreadPool(4,
                new InternalThreadFactory());
        setDevModeHandler(DevModeInitializer.initDevModeHandler(classes,
                context, executorService));
        CompletableFuture.runAsync(() -> {
            DevModeHandler devModeHandler = getDevModeHandler();
            if (devModeHandler instanceof AbstractDevServerRunner) {
                ((AbstractDevServerRunner) devModeHandler).waitForDevServer();
            } else if (devModeHandler instanceof DevBundleBuildingHandler devBundleBuilder) {
                devBundleBuilder.waitForDevBundle();
            }

            ApplicationConfiguration config = ApplicationConfiguration
                    .get(context);
            startWatchingThemeFolder(context, config);
            watchExternalDependencies(context, config);
            setFullyStarted(true);
        }, executorService);
        setDevModeStarted(context);
        this.browserLauncher = new BrowserLauncher(context);
    }

    private void shutdownExecutorService() {
        if (executorService != null) {
            executorService.shutdownNow();
        }
    }

    private void watchExternalDependencies(VaadinContext context,
            ApplicationConfiguration config) {
        File frontendFolder = FrontendUtils.getProjectFrontendDir(config);
        File jarFrontendResourcesFolder = FrontendUtils
                .getJarResourcesFolder(frontendFolder);
        registerWatcherShutdownCommand(new ExternalDependencyWatcher(context,
                jarFrontendResourcesFolder));

    }

    private void startWatchingThemeFolder(VaadinContext context,
            ApplicationConfiguration config) {

        if (config.getMode() != Mode.DEVELOPMENT_BUNDLE) {
            // Theme files are watched by Vite or app runs in prod mode
            return;
        }

        try {
            Optional<String> maybeThemeName = ThemeUtils.getThemeName(context);

            if (maybeThemeName.isEmpty()) {
                getLogger().debug("Found no custom theme in the project. "
                        + "Skipping watching the theme files");
                return;
            }
            List<String> activeThemes = ThemeUtils.getActiveThemes(context);
            for (String themeName : activeThemes) {
                File themeFolder = ThemeUtils.getThemeFolder(
                        FrontendUtils.getProjectFrontendDir(config), themeName);
                registerWatcherShutdownCommand(
                        new ThemeLiveUpdater(themeFolder, context));
            }
        } catch (Exception e) {
            getLogger().error("Failed to start live-reload for theme files", e);
        }
    }

    public void stopDevModeHandler() {
        if (devModeHandler != null) {
            devModeHandler.stop();
            devModeHandler = null;
        }
        shutdownExecutorService();
        for (Command shutdownCommand : shutdownCommands) {
            try {
                shutdownCommand.execute();
            } catch (Exception e) {
                getLogger().error("Failed to execute shut down command {}",
                        shutdownCommand.getClass().getName(), e);
            }
        }
        shutdownCommands.clear();

    }

    @Override
    public void launchBrowserInDevelopmentMode(String url) {
        browserLauncher.launchBrowserInDevelopmentMode(url);
    }

    @Override
    public void setApplicationUrl(String applicationUrl) {
        this.applicationUrl = applicationUrl;
        reportApplicationUrl();
    }

    private void setFullyStarted(boolean fullyStarted) {
        this.fullyStarted = fullyStarted;
        reportApplicationUrl();
    }

    private void reportApplicationUrl() {
        if (fullyStarted && applicationUrl != null) {
            getLogger().info("Application running at {}", applicationUrl);
        }
    }

    private void setDevModeStarted(VaadinContext context) {
        context.setAttribute(DevModeHandlerAlreadyStartedAttribute.class,
                new DevModeHandlerAlreadyStartedAttribute());
    }

    private void registerWatcherShutdownCommand(Closeable watcher) {
        registerShutdownCommand(() -> {
            try {
                watcher.close();
            } catch (Exception e) {
                getLogger().error("Failed to stop watcher {}",
                        watcher.getClass().getName(), e);
            }
        });
    }

    @Override
    public void registerShutdownCommand(Command command) {
        shutdownCommands.add(command);
    }

    /**
    * Shows whether {@link DevModeHandler} has been already started or not.
    *
    * @param context
    *            The {@link VaadinContext}, not <code>null</code>
    * @return <code>true</code> if {@link DevModeHandler} has already been
    *         started, <code>false</code> - otherwise
    */
    public static boolean isDevModeAlreadyStarted(VaadinContext context) {
        assert context != null;
        return context.getAttribute(
                DevModeHandlerAlreadyStartedAttribute.class) != null;
    }

    private static Logger getLogger() {
        return LoggerFactory.getLogger(DevModeHandlerManagerImpl.class);
    }

    private static class InternalThreadFactory implements ThreadFactory {
        private final AtomicInteger threadNumber = new AtomicInteger(1);

        @Override
        public Thread newThread(Runnable runnable) {
            String threadName = "vaadin-dev-server-"
                    + threadNumber.getAndIncrement();
            Thread thread = new Thread(runnable, threadName);
            thread.setDaemon(true);
            thread.setPriority(Thread.NORM_PRIORITY);
            return thread;
        }
    }
}
EOF

cat << EOF > src/main/java/com/vaadin/base/devserver/DevModeInitializer.java
/*
* Copyright 2000-2024 Vaadin Ltd.
*
* Licensed under the Apache License, Version 2.0 (the "License"); you may not
* use this file except in compliance with the License. You may obtain a copy of
* the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
* WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
* License for the specific language governing permissions and limitations under
* the License.
*/
package com.vaadin.base.devserver.startup;

import jakarta.servlet.annotation.HandlesTypes;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.Serializable;
import java.io.UncheckedIOException;
import java.lang.annotation.Annotation;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.net.URL;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.Collections;
import java.util.Enumeration;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionException;
import java.util.concurrent.Executor;
import java.util.concurrent.ForkJoinPool;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import org.apache.commons.io.IOUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vaadin.base.devserver.DevBundleBuildingHandler;
import com.vaadin.base.devserver.ViteHandler;
import com.vaadin.base.devserver.stats.DevModeUsageStatistics;
import com.vaadin.base.devserver.stats.StatisticsSender;
import com.vaadin.base.devserver.stats.StatisticsStorage;
import com.vaadin.base.devserver.viteproxy.ViteWebsocketEndpoint;
import com.vaadin.experimental.FeatureFlags;
import com.vaadin.flow.di.Lookup;
import com.vaadin.flow.internal.DevModeHandler;
import com.vaadin.flow.server.Constants;
import com.vaadin.flow.server.ExecutionFailedException;
import com.vaadin.flow.server.InitParameters;
import com.vaadin.flow.server.Mode;
import com.vaadin.flow.server.VaadinContext;
import com.vaadin.flow.server.VaadinServlet;
import com.vaadin.flow.server.frontend.FrontendUtils;
import com.vaadin.flow.server.frontend.NodeTasks;
import com.vaadin.flow.server.frontend.Options;
import com.vaadin.flow.server.frontend.scanner.ClassFinder;
import com.vaadin.flow.server.frontend.scanner.ClassFinder.DefaultClassFinder;
import com.vaadin.flow.server.startup.ApplicationConfiguration;
import com.vaadin.flow.server.startup.VaadinInitializerException;
import com.vaadin.pro.licensechecker.LicenseChecker;

import static com.vaadin.flow.server.Constants.PACKAGE_JSON;
import static com.vaadin.flow.server.Constants.PROJECT_FRONTEND_GENERATED_DIR_TOKEN;
import static com.vaadin.flow.server.Constants.VAADIN_SERVLET_RESOURCES;
import static com.vaadin.flow.server.Constants.VAADIN_WEBAPP_RESOURCES;
import static com.vaadin.flow.server.InitParameters.NPM_EXCLUDE_WEB_COMPONENTS;
import static com.vaadin.flow.server.InitParameters.REACT_ENABLE;
import static com.vaadin.flow.server.InitParameters.SERVLET_PARAMETER_DEVMODE_OPTIMIZE_BUNDLE;
import static com.vaadin.flow.server.frontend.FrontendUtils.GENERATED;

/**
* Initializer for starting node updaters as well as the dev mode server.
* <p>
* For internal use only. May be renamed or removed in a future release.
*
* @since 2.0
*/
public class DevModeInitializer implements Serializable {

    static class DevModeClassFinder extends DefaultClassFinder {

        private static final Set<String> APPLICABLE_CLASS_NAMES = Collections
                .unmodifiableSet(calculateApplicableClassNames());

        public DevModeClassFinder(Set<Class<?>> classes) {
            super(classes);
        }

        @Override
        public Set<Class<?>> getAnnotatedClasses(
                Class<? extends Annotation> annotation) {
            ensureImplementation(annotation);
            return super.getAnnotatedClasses(annotation);
        }

        @Override
        public <T> Set<Class<? extends T>> getSubTypesOf(Class<T> type) {
            ensureImplementation(type);
            return super.getSubTypesOf(type);
        }

        private void ensureImplementation(Class<?> clazz) {
            if (!APPLICABLE_CLASS_NAMES.contains(clazz.getName())) {
                throw new IllegalArgumentException("Unexpected class name "
                        + clazz + ". Implementation error: the class finder "
                        + "instance is not aware of this class. "
                        + "Fix @HandlesTypes annotation value for "
                        + DevModeStartupListener.class.getName());
            }
        }

        private static Set<String> calculateApplicableClassNames() {
            HandlesTypes handlesTypes = DevModeStartupListener.class
                    .getAnnotation(HandlesTypes.class);
            return Stream.of(handlesTypes.value()).map(Class::getName)
                    .collect(Collectors.toSet());
        }
    }

    private static final Pattern JAR_FILE_REGEX = Pattern
            .compile(".*file:(.+\\\.jar).*");

    // Path of jar files in a URL with zip protocol doesn't start with
    // "zip:"
    // nor "file:". It contains only the path of the file.
    // Weblogic uses zip protocol.
    private static final Pattern ZIP_PROTOCOL_JAR_FILE_REGEX = Pattern
            .compile("(.+\\\.jar).*");

    private static final Pattern VFS_FILE_REGEX = Pattern
            .compile("(vfs:/.+\\\.jar).*");

    private static final Pattern VFS_DIRECTORY_REGEX = Pattern
            .compile("vfs:/.+");

    // allow trailing slash
    private static final Pattern DIR_REGEX_FRONTEND_DEFAULT = Pattern.compile(
            "^(?:file:0)?(.+)" + Constants.RESOURCES_FRONTEND_DEFAULT + "/?$");

    // allow trailing slash
    private static final Pattern DIR_REGEX_RESOURCES_JAR_DEFAULT = Pattern
            .compile("^(?:file:0)?(.+)" + Constants.RESOURCES_THEME_JAR_DEFAULT
                    + "/?$");

    // allow trailing slash
    private static final Pattern DIR_REGEX_COMPATIBILITY_FRONTEND_DEFAULT = Pattern
            .compile("^(?:file:)?(.+)"
                    + Constants.COMPATIBILITY_RESOURCES_FRONTEND_DEFAULT
                    + "/?$");

    /**
    * Initialize the devmode server if not in production mode or compatibility
    * mode.
    * <p>
    * </p>
    * Uses common ForkJoin pool to execute asynchronous tasks. It is
    * recommended to use
    * {@link #initDevModeHandler(Set, VaadinContext, Executor)} and provide a a
    * custom executor if initialization starts long-running tasks.
    *
    * @param classes
    *            classes to check for npm- and js modules
    * @param context
    *            VaadinContext we are running in
    * @return the initialized dev mode handler or {@code null} if none was
    *         created
    *
    * @throws VaadinInitializerException
    *             if dev mode can't be initialized
    * @deprecated use {@link #initDevModeHandler(Set, VaadinContext, Executor)}
    *             providing a custom executor.
    */
    @Deprecated(forRemoval = true)
    public static DevModeHandler initDevModeHandler(Set<Class<?>> classes,
            VaadinContext context) throws VaadinInitializerException {
        return initDevModeHandler(classes, context, ForkJoinPool.commonPool());
    }

    /**
    * Initialize the devmode server if not in production mode or compatibility
    * mode.
    *
    * @param classes
    *            classes to check for npm- and js modules
    * @param context
    *            VaadinContext we are running in
    * @param taskExecutor
    *            the executor to use for asynchronous execution
    * @return the initialized dev mode handler or {@code null} if none was
    *         created
    *
    * @throws VaadinInitializerException
    *             if dev mode can't be initialized
    */
    public static DevModeHandler initDevModeHandler(Set<Class<?>> classes,
            VaadinContext context, Executor taskExecutor)
            throws VaadinInitializerException {

        ApplicationConfiguration config = ApplicationConfiguration.get(context);
        if (config.isProductionMode()) {
            log().debug("Skipping DEV MODE because PRODUCTION MODE is set.");
            return null;
        }

        // This needs to be set as there is no "current service" available in
        // this call
        FeatureFlags featureFlags = FeatureFlags.get(context);
        LicenseChecker.setStrictOffline(true);

        featureFlags.setPropertiesLocation(config.getJavaResourceFolder());

        File baseDir = config.getProjectFolder();

        // Initialize the usage statistics if enabled
        if (config.isUsageStatisticsEnabled()) {
            StatisticsStorage storage = new StatisticsStorage();
            DevModeUsageStatistics.init(baseDir, storage,
                    new StatisticsSender(storage));
        }

        File frontendFolder = config.getFrontendFolder();

        Lookup lookupFromContext = context.getAttribute(Lookup.class);
        Lookup lookupForClassFinder = Lookup.of(new DevModeClassFinder(classes),
                ClassFinder.class);
        Lookup lookup = Lookup.compose(lookupForClassFinder, lookupFromContext);
        Options options = new Options(lookup, baseDir)
                .withFrontendDirectory(frontendFolder)
                .withFrontendGeneratedFolder(
                        new File(frontendFolder + GENERATED))
                .withBuildDirectory(config.getBuildFolder());

        log().info("Starting dev-mode updaters in {} folder.",
                options.getNpmFolder());

        // Regenerate Vite configuration, as it may be necessary to
        // update it
        // TODO: make sure target directories are aligned with build
        // config,
        // see https://github.com/vaadin/flow/issues/9082
        File target = new File(baseDir, config.getBuildFolder());
        options.withBuildResultFolders(
                Paths.get(target.getPath(), "classes", VAADIN_WEBAPP_RESOURCES)
                        .toFile(),
                Paths.get(target.getPath(), "classes", VAADIN_SERVLET_RESOURCES)
                        .toFile());

        // If we are missing either the base or generated package json
        // files generate those
        if (!new File(options.getNpmFolder(), PACKAGE_JSON).exists()) {
            options.createMissingPackageJson(true);
        }

        Set<File> frontendLocations = getFrontendLocationsFromClassloader(
                DevModeStartupListener.class.getClassLoader());

        boolean useByteCodeScanner = config.getBooleanProperty(
                SERVLET_PARAMETER_DEVMODE_OPTIMIZE_BUNDLE,
                Boolean.parseBoolean(System.getProperty(
                        SERVLET_PARAMETER_DEVMODE_OPTIMIZE_BUNDLE,
                        Boolean.FALSE.toString())));

        boolean enablePnpm = config.isPnpmEnabled();
        boolean enableBun = config.isBunEnabled();

        boolean useGlobalPnpm = config.isGlobalPnpm();

        boolean useHomeNodeExec = config.getBooleanProperty(
                InitParameters.REQUIRE_HOME_NODE_EXECUTABLE, false);

        String[] additionalPostinstallPackages = config
                .getStringProperty(
                        InitParameters.ADDITIONAL_POSTINSTALL_PACKAGES, "")
                .split(",");

        String frontendGeneratedFolderName = config.getStringProperty(
                PROJECT_FRONTEND_GENERATED_DIR_TOKEN,
                Paths.get(frontendFolder.getPath(), GENERATED).toString());
        File frontendGeneratedFolder = new File(frontendGeneratedFolderName);
        File jarFrontendResourcesFolder = new File(frontendGeneratedFolder,
                FrontendUtils.JAR_RESOURCES_FOLDER);
        Mode mode = config.getMode();
        boolean reactEnable = config.getBooleanProperty(REACT_ENABLE,
                FrontendUtils
                        .isReactRouterRequired(options.getFrontendDirectory()));

        boolean npmExcludeWebComponents = config
                .getBooleanProperty(NPM_EXCLUDE_WEB_COMPONENTS, false);

        options.enablePackagesUpdate(true)
                .useByteCodeScanner(useByteCodeScanner)
                .withFrontendGeneratedFolder(frontendGeneratedFolder)
                .withJarFrontendResourcesFolder(jarFrontendResourcesFolder)
                .copyResources(frontendLocations)
                .copyLocalResources(new File(baseDir,
                        Constants.LOCAL_FRONTEND_RESOURCES_PATH))
                .enableImportsUpdate(true)
                .withRunNpmInstall(mode == Mode.DEVELOPMENT_FRONTEND_LIVERELOAD)
                .withEmbeddableWebComponents(true).withEnablePnpm(enablePnpm)
                .withEnableBun(enableBun).useGlobalPnpm(useGlobalPnpm)
                .withHomeNodeExecRequired(useHomeNodeExec)
                .withProductionMode(config.isProductionMode())
                .withPostinstallPackages(
                        Arrays.asList(additionalPostinstallPackages))
                .withFrontendHotdeploy(
                        mode == Mode.DEVELOPMENT_FRONTEND_LIVERELOAD)
                .withBundleBuild(mode == Mode.DEVELOPMENT_BUNDLE)
                .withFrontendExtraFileExtensions(
                        getFrontendExtraFileExtensions(config))
                .withReact(reactEnable)
                .withNpmExcludeWebComponents(npmExcludeWebComponents);

        // Do not execute inside runnable thread as static mocking doesn't work.
        NodeTasks tasks = new NodeTasks(options);
        Runnable runnable = () -> {
            runNodeTasks(tasks);
            if (mode == Mode.DEVELOPMENT_FRONTEND_LIVERELOAD) {
                // For Vite, wait until a VaadinServlet is deployed so we know
                // which frontend servlet path to use
                if (VaadinServlet.getFrontendMapping() == null) {
                    log().debug("Waiting for a VaadinServlet to be deployed");
                    while (VaadinServlet.getFrontendMapping() == null) {
                        try {
                            Thread.sleep(100);
                        } catch (InterruptedException e) {
                        }
                    }
                }
            }
        };

        CompletableFuture<Void> nodeTasksFuture = CompletableFuture
                .runAsync(runnable, taskExecutor);

        Lookup devServerLookup = Lookup.compose(lookup,
                Lookup.of(config, ApplicationConfiguration.class));
        int port = Integer
                .parseInt(config.getStringProperty("devServerPort", "0"));
        if (mode == Mode.DEVELOPMENT_BUNDLE) {
            // Shows a "build in progress" page during dev bundle creation
            return new DevBundleBuildingHandler(nodeTasksFuture);
        } else {
            ViteHandler handler = new ViteHandler(devServerLookup, port,
                    options.getNpmFolder(), nodeTasksFuture);
            VaadinServlet.whenFrontendMappingAvailable(
                    () -> ViteWebsocketEndpoint.init(context, handler));
            return handler;
        }
    }

    private static List<String> getFrontendExtraFileExtensions(
            ApplicationConfiguration config) {
        List<String> stringProperty = Arrays.asList(config
                .getStringProperty(InitParameters.FRONTEND_EXTRA_EXTENSIONS, "")
                .split(","));
        return stringProperty;
    }

    private static Logger log() {
        return LoggerFactory.getLogger(DevModeStartupListener.class);
    }

    /*
    * This method returns all folders of jar files having files in the
    * META-INF/resources/frontend and META-INF/resources/themes folder. We
    * don't use URLClassLoader because will fail in Java 9+
    */
    static Set<File> getFrontendLocationsFromClassloader(
            ClassLoader classLoader) throws VaadinInitializerException {
        Set<File> frontendFiles = new HashSet<>();
        frontendFiles.addAll(getFrontendLocationsFromClassloader(classLoader,
                Constants.RESOURCES_FRONTEND_DEFAULT));
        frontendFiles.addAll(getFrontendLocationsFromClassloader(classLoader,
                Constants.COMPATIBILITY_RESOURCES_FRONTEND_DEFAULT));
        frontendFiles.addAll(getFrontendLocationsFromClassloader(classLoader,
                Constants.RESOURCES_THEME_JAR_DEFAULT));
        return frontendFiles;
    }

    private static void runNodeTasks(NodeTasks tasks) {
        try {
            tasks.execute();
        } catch (ExecutionFailedException exception) {
            log().debug(
                    "Could not initialize dev mode handler. One of the node tasks failed",
                    exception);
            throw new CompletionException(exception);
        }
    }

    private static Set<File> getFrontendLocationsFromClassloader(
            ClassLoader classLoader, String resourcesFolder)
            throws VaadinInitializerException {
        Set<File> frontendFiles = new HashSet<>();
        try {
            Enumeration<URL> en = classLoader.getResources(resourcesFolder);
            if (en == null) {
                return frontendFiles;
            }
            Set<String> vfsJars = new HashSet<>();
            while (en.hasMoreElements()) {
                URL url = en.nextElement();
                String urlString = url.toString();

                String path = URLDecoder.decode(url.getPath(),
                        StandardCharsets.UTF_8.name());
                Matcher jarMatcher = JAR_FILE_REGEX.matcher(path);
                Matcher zipProtocolJarMatcher = ZIP_PROTOCOL_JAR_FILE_REGEX
                        .matcher(path);
                Matcher dirMatcher = DIR_REGEX_FRONTEND_DEFAULT.matcher(path);
                Matcher dirResourcesMatcher = DIR_REGEX_RESOURCES_JAR_DEFAULT
                        .matcher(path);
                Matcher dirCompatibilityMatcher = DIR_REGEX_COMPATIBILITY_FRONTEND_DEFAULT
                        .matcher(path);
                Matcher jarVfsMatcher = VFS_FILE_REGEX.matcher(urlString);
                Matcher dirVfsMatcher = VFS_DIRECTORY_REGEX.matcher(urlString);
                if (jarVfsMatcher.find()) {
                    String vfsJar = jarVfsMatcher.group(1);
                    if (vfsJars.add(vfsJar)) { // NOSONAR
                        frontendFiles.add(
                                getPhysicalFileOfJBossVfsJar(new URL(vfsJar)));
                    }
                } else if (dirVfsMatcher.find()) {
                    URL vfsDirUrl = new URL(urlString.substring(0,
                            urlString.lastIndexOf(resourcesFolder)));
                    frontendFiles
                            .add(getPhysicalFileOfJBossVfsDirectory(vfsDirUrl));
                } else if (jarMatcher.find()) {
                    frontendFiles.add(new File(jarMatcher.group(1)));
                } else if ("zip".equalsIgnoreCase(url.getProtocol())
                        && zipProtocolJarMatcher.find()) {
                    frontendFiles.add(new File(zipProtocolJarMatcher.group(1)));
                } else if (dirMatcher.find()) {
                    frontendFiles.add(new File(dirMatcher.group(1)));
                } else if (dirResourcesMatcher.find()) {
                    frontendFiles.add(new File(dirResourcesMatcher.group(1)));
                } else if (dirCompatibilityMatcher.find()) {
                    frontendFiles
                            .add(new File(dirCompatibilityMatcher.group(1)));
                } else {
                    log().warn(
                            "Resource {} not visited because does not meet supported formats.",
                            url.getPath());
                }
            }
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }

        return frontendFiles;
    }

    private static File getPhysicalFileOfJBossVfsDirectory(URL url)
            throws IOException, VaadinInitializerException {
        try {
            Object virtualFile = url.openConnection().getContent();
            Class virtualFileClass = virtualFile.getClass();

            // Reflection as we cannot afford a dependency to
            // WildFly or JBoss
            Method getChildrenRecursivelyMethod = virtualFileClass
                    .getMethod("getChildrenRecursively");
            Method getPhysicalFileMethod = virtualFileClass
                    .getMethod("getPhysicalFile");

            // By calling getPhysicalFile, we make sure that the
            // corresponding
            // physical files/directories of the root directory and
            // its children
            // are created. Later, these physical files are scanned
            // to collect
            // their resources.
            List virtualFiles = (List) getChildrenRecursivelyMethod
                    .invoke(virtualFile);
            File rootDirectory = (File) getPhysicalFileMethod
                    .invoke(virtualFile);
            for (Object child : virtualFiles) {
                // side effect: create real-world files
                getPhysicalFileMethod.invoke(child);
            }
            return rootDirectory;
        } catch (NoSuchMethodException | IllegalAccessException
                | InvocationTargetException exc) {
            throw new VaadinInitializerException(
                    "Failed to invoke JBoss VFS API.", exc);
        }
    }

    private static File getPhysicalFileOfJBossVfsJar(URL url)
            throws IOException, VaadinInitializerException {
        try {
            Object jarVirtualFile = url.openConnection().getContent();

            // Creating a temporary jar file out of the vfs files
            String vfsJarPath = url.toString();
            String fileNamePrefix = vfsJarPath.substring(
                    vfsJarPath.lastIndexOf(
                            vfsJarPath.contains("\\\") ? '\\\' : '/') + 1,
                    vfsJarPath.lastIndexOf(".jar"));
            Path tempJar = Files.createTempFile(fileNamePrefix, ".jar");

            generateJarFromJBossVfsFolder(jarVirtualFile, tempJar);

            File tempJarFile = tempJar.toFile();
            tempJarFile.deleteOnExit();
            return tempJarFile;
        } catch (NoSuchMethodException | IllegalAccessException
                | InvocationTargetException exc) {
            throw new VaadinInitializerException(
                    "Failed to invoke JBoss VFS API.", exc);
        }
    }

    private static void generateJarFromJBossVfsFolder(Object jarVirtualFile,
            Path tempJar) throws IOException, IllegalAccessException,
            InvocationTargetException, NoSuchMethodException {
        // We should use reflection to use JBoss VFS API as we cannot
        // afford a
        // dependency to WildFly or JBoss
        Class virtualFileClass = jarVirtualFile.getClass();
        Method getChildrenRecursivelyMethod = virtualFileClass
                .getMethod("getChildrenRecursively");
        Method openStreamMethod = virtualFileClass.getMethod("openStream");
        Method isFileMethod = virtualFileClass.getMethod("isFile");
        Method getPathNameRelativeToMethod = virtualFileClass
                .getMethod("getPathNameRelativeTo", virtualFileClass);

        List jarVirtualChildren = (List) getChildrenRecursivelyMethod
                .invoke(jarVirtualFile);
        try (ZipOutputStream zipOutputStream = new ZipOutputStream(
                Files.newOutputStream(tempJar))) {
            for (Object child : jarVirtualChildren) {
                if (!(Boolean) isFileMethod.invoke(child))
                    continue;

                String relativePath = (String) getPathNameRelativeToMethod
                        .invoke(child, jarVirtualFile);
                InputStream inputStream = (InputStream) openStreamMethod
                        .invoke(child);
                ZipEntry zipEntry = new ZipEntry(relativePath);
                zipOutputStream.putNextEntry(zipEntry);
                IOUtils.copy(inputStream, zipOutputStream);
                zipOutputStream.closeEntry();
            }
        }
    }
}          
EOF

find src/main/java/ -type f -name "*.java" 

}
