package com.vaadin.parameter;

import java.util.List;

import com.beust.jcommander.Parameter;
import com.beust.jcommander.Parameters;
import com.beust.jcommander.converters.CommaParameterSplitter;

@Parameters(separators = "=", commandDescription = "Arguments for the Platform in Test (PiT) script.")
public class PitArguments {

    
    // @Parameter(names = "--starters", description = "Comma-separated list of starter projects to test.", splitter = CommaParameterSplitter.class, variableArity = true)
    // public List<String> starters;

    // @Parameter(names = "--demos", description = "Comma-separated list of demo projects to test.", splitter = CommaParameterSplitter.class, variableArity = true)
    // public List<String> demos;

    //separation between demo and starters seems arbitrary, we just launch everything with one parameter
    @Parameter(names = "--run", description = "Comma-separated list of demo projects to test.", splitter = CommaParameterSplitter.class, variableArity = true)
    public List<String> toRun;

    @Parameter(names = "--version", description = "The Vaadin version to use for the test(s).")
    public String version;

    @Parameter(names = "--javaVersion", description = "The Java version to use for the test(s).")
    String javaVersion = "21";

    @Parameter(names = "--port", description = "The port number for the application server.")
    public Integer port = 8080;

    @Parameter(names = "--mode", description = "The test mode, typically 'dev' or 'prod'.")
    public String mode = "dev";

    @Parameter(names = "--tmp", description = "Specifies the path to the temporary directory.")
    public String tmpDir = "tmp";

    @Parameter(names = "--mvn-args", description = "Passes additional arguments to Maven.")
    public String mvnArgs;

    @Parameter(names = "--mvn-opts", description = "Sets MAVEN_OPTS for the Maven process.")
    public String mvnOpts;

    @Parameter(names = "--clean", description = "A flag to clean the temporary folder before the run.")
    public boolean clean = false;

    @Parameter(names = "--offline", description = "A flag to run build tools in offline mode.")
    public boolean offline = false;

    @Parameter(names = "--verbose", description = "A flag to enable detailed, verbose output.")
    public boolean verbose = false;

    @Parameter(names = {"--interactive", "--stepwise"}, description = "A flag to pause the script for manual user testing.")
    public boolean interactive = false;

    @Parameter(names = "--test", description = "A flag to run in 'test mode,' which prints commands without executing them.")
    public boolean testMode = false;

    @Parameter(names = {"--skip-tests", "--skiptests"}, description = "A flag to skip the test execution phase.")
    public boolean skipTests = false;

    @Parameter(names = "--skip-pw", description = "A flag to skip running Playwright UI tests.")
    public boolean skipPw = false;

    @Parameter(names = "--pnpm", description = "A flag to enable pnpm for frontend dependencies.")
    public boolean pnpm = false;

    @Parameter(names = "--vite", description = "A flag to enable Vite for the frontend.")
    public boolean vite = false;

    @Parameter(names = "--git-ssh", description = "A flag to use SSH instead of HTTPS for Git operations.")
    public boolean gitSsh = false;

    @Parameter(names = "--help", help = true, description = "Displays this help message.")
    public boolean help;

}
