package com.vaadin.utils;

import java.io.File;
import java.io.IOException;

public class POMUtils {

    public static void setJavaVersionProperty(File pom, String javaVersion) throws IOException {
        // Logic to write javaVersionProperty to the pom.xml at pomFilePath
    }

    public static String getJavaVersionProperty() {
        return "<maven.compiler.source>21</maven.compiler.source>\n" +
               "<maven.compiler.target>21</maven.compiler.target>";
    }

    public static String getJavaVersionPropertyWithCompilerOptions() {
        return "<maven.compiler.source>21</maven.compiler.source>\n" +
               "<maven.compiler.target>21</maven.compiler.target>\n" +
               "<maven.compiler.release>21</maven.compiler.release>";
    }
    
}
