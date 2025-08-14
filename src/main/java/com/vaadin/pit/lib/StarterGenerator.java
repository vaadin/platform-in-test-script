package com.vaadin.pit.lib;

import java.io.File;
import java.io.IOException;
import java.util.List;

public class StarterGenerator {
    public static void generateStarter(String name, File workingDir) throws IOException, InterruptedException {
        String cmd = null;
        if (name.endsWith("spring")) {
            cmd = "mvn -ntp -q -B archetype:generate -DarchetypeGroupId=com.vaadin -DarchetypeArtifactId=vaadin-archetype-spring-application -DarchetypeVersion=LATEST -DgroupId=com.vaadin.starter -DartifactId=" + name;
        } else if (name.startsWith("archetype")) {
            cmd = "mvn -ntp -q -B archetype:generate -DarchetypeGroupId=com.vaadin -DarchetypeArtifactId=vaadin-archetype-application -DarchetypeVersion=LATEST -DgroupId=com.vaadin.starter -DartifactId=" + name;
        } else if (name.equals("vaadin-quarkus")) {
            cmd = "mvn -ntp -q -B io.quarkus.platform:quarkus-maven-plugin:create -Dextensions=vaadin -DwithCodestart -DprojectGroupId=com.vaadin.starter -DprojectArtifactId=" + name;
        } else if (name.startsWith("hilla-") && name.endsWith("-cli")) {
            cmd = "npx @hilla/cli init --react " + name;
        }
        if (cmd != null) {
            runCommand(workingDir, cmd);
            File newDir = new File(workingDir, name);
            if (newDir.exists()) {
                GitUtils.initGitRepo(newDir);
            }
        } else {
            throw new IllegalArgumentException("Unknown starter type: " + name);
        }
    }

    private static void runCommand(File dir, String command) throws IOException, InterruptedException {
        ProcessBuilder pb = new ProcessBuilder(command.split(" "));
        pb.directory(dir);
        pb.inheritIO();
        Process p = pb.start();
        int exit = p.waitFor();
        if (exit != 0) throw new IOException("Command failed: " + command);
    }
}
