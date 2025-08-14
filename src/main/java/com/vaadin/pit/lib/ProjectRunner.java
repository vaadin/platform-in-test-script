package com.vaadin.pit.lib;

import java.io.File;
import java.io.IOException;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.vaadin.runner.GradleRunner;
import com.vaadin.runner.MavenRunner;
import com.vaadin.runner.Runner;

public class ProjectRunner {

    private static final Logger LOGGER = Logger.getLogger(ProjectRunner.class.getName());
    private static List<Runner> runners = List.of(
        new MavenRunner(),
        new GradleRunner()
    );


    public static void run(String preset, File tmpDir, int port, String version, boolean offline, boolean verbose) throws IOException, InterruptedException {
        File starterDir = new File(tmpDir, preset.replace('_', '-'));
        if (!offline || !starterDir.exists()) {
            if (starterDir.exists()) {
                deleteDirectory(starterDir);
            }
            if (preset.startsWith("archetype") || preset.equals("vaadin-quarkus") || preset.endsWith("-cli")) {
                StarterGenerator.generateStarter(preset, tmpDir);
            } else {
                StarterDownloader.downloadAndUnzipStarter(preset, tmpDir, verbose);
            }
        }
        GitUtils.initGitRepo(starterDir);
        // Step 1: Validate project after generation/download
    runValidations(starterDir, "post-setup");

        // Step 2: Set project version if specified
        if (version != null && !version.isEmpty()) {
            setProjectVersion(starterDir, version);
        }

        // Step 3: Validate project after version change
        runValidations(starterDir, "post-version");

        // Step 4: Run custom commands (e.g., build, test, run)
        runProjectCommands(starterDir, preset, port, verbose);
    }

    private static void deleteDirectory(File dir) throws IOException {
        if (dir.isDirectory()) {
            for (File file : dir.listFiles()) {
                deleteDirectory(file);
            }
        }
        dir.delete();
    }

    // Stub for validations (can be expanded as needed)
    private static void runValidations(File projectDir, String phase) {
        // Example: run linter, check files, etc.
    LOGGER.info("[Validation] Phase: " + phase + " for " + projectDir.getAbsolutePath());
    }

    // Stub for versioning (can be expanded to edit pom.xml/build.gradle)
    private static void setProjectVersion(File projectDir, String version) {
        // Example: update pom.xml or build.gradle
    LOGGER.info("[Versioning] Setting version to " + version + " in " + projectDir.getAbsolutePath());
        // TODO: Use Maven Model or Gradle Tooling API for real implementation
    }

    // Run project commands (build, test, run, etc.) and echo output live
    private static void runProjectCommands(File projectDir, String preset, int port, boolean verbose) {
        String buildCmd = StarterCommands.getCompileProdCommand(preset);
        String runDevCmd = StarterCommands.getRunDevCommand(preset);
        LOGGER.info("[Command] Building project: " + buildCmd);
        try {
            runShellCommand(buildCmd, projectDir);
        } catch (Exception e) {
            LOGGER.log(Level.SEVERE, "Build failed", e);
            return;
        }
        LOGGER.info("[Command] Running project in dev mode: " + runDevCmd);
        try {
            runShellCommand(runDevCmd, projectDir);
        } catch (Exception e) {
            LOGGER.log(Level.SEVERE, "Run failed", e);
        }
    }

    // Helper to run a shell command and echo output live
    private static void runShellCommand(String command, File workingDir) throws IOException, InterruptedException {
        String[] cmdArray;
        if (System.getProperty("os.name").toLowerCase().contains("win")) {
            cmdArray = new String[] { "cmd.exe", "/c", command };
        } else {
            cmdArray = new String[] { "/bin/sh", "-c", command };
        }
        ProcessBuilder pb = new ProcessBuilder(cmdArray);
        pb.directory(workingDir);
        pb.inheritIO();
        Process p = pb.start();
        int exit = p.waitFor();
        if (exit != 0) throw new IOException("Command failed with exit code " + exit);
    }
}
