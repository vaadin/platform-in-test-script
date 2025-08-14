package com.vaadin.pit.lib;

public class StarterCommands {
    public static String getCleanCommand(String starterName) {
        if (starterName.startsWith("initializer-") && starterName.contains("-gradle")) {
            return "./gradlew clean";
        }
        return "mvn -ntp -B clean";
    }

    public static String getCompileProdCommand(String starterName) {
        if (starterName.equals("archetype-hotswap") || starterName.equals("archetype-jetty")) {
            return "mvn -ntp -B clean";
        }
        if (starterName.startsWith("initializer-") && starterName.contains("-gradle")) {
            return "./gradlew clean build -Dhilla.productionMode -Dvaadin.productionMode && rm -f ./build/libs/*-plain.jar";
        }
        return "mvn -ntp -B -Pproduction clean package";
    }

    public static String getRunDevCommand(String starterName) {
        if (starterName.equals("vaadin-quarkus")) {
            return "mvn -ntp -B quarkus:dev";
        }
        if (starterName.startsWith("initializer-") && starterName.contains("-maven")) {
            return "mvn -ntp -B spring-boot:run";
        }
        if (starterName.startsWith("initializer-") && starterName.contains("-gradle")) {
            return "./gradlew bootRun";
        }
        return "mvn -ntp -B";
    }

    public static String getRunProdCommand(String starterName) {
        if (starterName.equals("archetype-hotswap") || starterName.equals("archetype-jetty")) {
            return "mvn -ntp -B -Pproduction -Dvaadin.productionMode jetty:run-war";
        }
        if (starterName.equals("vaadin-quarkus")) {
            return "java -jar target/quarkus-app/quarkus-run.jar";
        }
        if (starterName.contains("gradle")) {
            return "java -jar ./build/libs/*.jar";
        }
        return "java -jar -Dvaadin.productionMode target/*.jar";
    }
}
