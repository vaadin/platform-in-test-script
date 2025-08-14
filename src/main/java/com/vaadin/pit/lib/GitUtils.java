package com.vaadin.pit.lib;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

public class GitUtils {
    public static void initGitRepo(File dir) throws IOException, InterruptedException {
        File gitDir = new File(dir, ".git");
        if (gitDir.exists()) return;
        runCommand(dir, List.of("git", "init", "-q"));
        if (!runCommand(dir, List.of("git", "config", "user.email")).contains("@")) {
            runCommand(dir, List.of("git", "config", "user.email", "vaadin-bot@vaadin.com"));
        }
        if (!runCommand(dir, List.of("git", "config", "user.name")).contains("Vaadin")) {
            runCommand(dir, List.of("git", "config", "user.name", "Vaadin Bot"));
        }
        runCommand(dir, List.of("git", "config", "advice.addIgnoredFile", "false"));
        // Add all files (including dotfiles)
        runCommand(dir, List.of("git", "add", "."));
        runCommand(dir, List.of("git", "commit", "-q", "-m", "First commit", "-a"));
    }

    private static String runCommand(File dir, List<String> command) throws IOException, InterruptedException {
        ProcessBuilder pb = new ProcessBuilder(command);
        pb.directory(dir);
        pb.redirectErrorStream(true);
        Process process = pb.start();
        String output = new String(process.getInputStream().readAllBytes());
        process.waitFor();
        return output;
    }
}
