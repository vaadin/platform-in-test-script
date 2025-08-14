package com.vaadin.pit;


import java.io.File;
import java.io.IOException;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Arrays;

import com.beust.jcommander.JCommander;
import com.vaadin.parameter.PitArguments;
import com.vaadin.pit.lib.ProjectRunner;

public class Pit {

    // run without parameters to get help
    public static void main(String[] args) {
        // args = new String[]{
        //     " --verbose",
        //     "--starters",
        //     "spreadsheet-demo",
        //     "archetype-jetty,archetype-swing",
        //     "--test"
        // };

        var commandArgs = new PitArguments();
        var jc = JCommander.newBuilder()
            .addObject(commandArgs)
            .build();

        jc.parse(args);

        if (commandArgs.help) {
            jc.usage();
            return;
        }

        if (commandArgs.toRun.isEmpty()) {
            System.err.println("No projects specified to run. Use --run <project1,project2,...> to specify projects.");
            jc.usage();
            return;
        }else{

            try {
                Files.createDirectories(Paths.get(commandArgs.tmpDir));
            } catch (IOException e) {
                e.printStackTrace();
                return;
            }

            for(String starter : commandArgs.toRun) {
                try {
                    ProjectRunner.run(starter, new File(commandArgs.tmpDir), 
                        commandArgs.port, commandArgs.version, commandArgs.offline, commandArgs.verbose);
                } catch (IOException | InterruptedException e) {
                    e.printStackTrace();
                    return;
                }
            }
        }

        // System.out.println("--- Parsed PiT Arguments ---");
        System.out.println("To run: " + commandArgs.toRun.size()+":"+Arrays.toString(commandArgs.toRun.toArray()));
        System.out.println("Version: " + commandArgs.version);
        System.out.println("Port: " + commandArgs.port);
        System.out.println("Mode: " + commandArgs.mode);
        System.out.println("Temp Directory: " + commandArgs.tmpDir);
        System.out.println("Clean: " + commandArgs.clean);
        System.out.println("Offline: " + commandArgs.offline);
        System.out.println("Verbose: " + commandArgs.verbose);
        System.out.println("Interactive: " + commandArgs.interactive);
        System.out.println("Test Mode: " + commandArgs.testMode);
        System.out.println("Skip Tests: " + commandArgs.skipTests);
        // System.out.println("Skip Playwright: " + commandArgs.skipPw);
        // System.out.println("Enable pnpm: " + commandArgs.pnpm);
        // System.out.println("Enable Vite: " + commandArgs.vite);
        // System.out.println("Use Git SSH: " + commandArgs.gitSsh);
        // System.out.println("Maven Args: " + commandArgs.mvnArgs);
        // System.out.println("Maven Opts: " + commandArgs.mvnOpts);
        // System.out.println("--------------------------");
    }
}
