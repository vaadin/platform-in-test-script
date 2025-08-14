package com.vaadin.pit.lib;

public class StarterTestFile {
    public static String getTestFile(String starterName) {
        if (starterName.contains("-auth")) return "start-auth.js";
        if (starterName.startsWith("flow-crm-tutorial")) return "";
        if (starterName.equals("react-tutorial")) return "react.js";
        if (starterName.startsWith("default") || starterName.equals("vaadin-quarkus") || starterName.endsWith("_prerelease")) return "hello.js";
        if (starterName.startsWith("initializer")) return "initializer.js";
        if (starterName.startsWith("archetype")) return "click-hotswap.js";
        if (starterName.equals("hilla-react-cli")) return "hilla-react-cli.js";
        if (starterName.equals("react")) return "react-starter.js";
        if (starterName.startsWith("test-hybrid-react")) return "hybrid-react.js";
        if (starterName.startsWith("test-hybrid")) return "hybrid.js";
        if (starterName.equals("react-crm-tutorial")) return "noop.js";
        if (starterName.equals("collaboration")) return "collaboration.js";
        return "start.js";
    }
}
