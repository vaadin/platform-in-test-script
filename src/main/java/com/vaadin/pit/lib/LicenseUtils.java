package com.vaadin.pit.lib;

public class LicenseUtils {
    public static boolean needsLicense(String starterName) {
        return !(starterName.startsWith("default") || starterName.startsWith("archetype"));
    }
}
