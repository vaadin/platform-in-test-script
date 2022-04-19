# [vaadin-starter-installer]

# How To Use

`./vaadin-starter-installer project version branch`

Tip: `./vaadin-starter-installer all version branch` will test all the starters.

Note: Ctrl-C interrupts the server and continues the script.


# How The Installer Works

The installer takes three arguments: the name of the project(base-starter-flow-cdi, or all -- for testing all projects -- for example), the version that you want to test, and a branch.

The script works by first calling the main function with all the arguments, then calling different setup functions with those arguments that were passed to main.

The script almost always only outputs "this compilation succeeded" messages and errors. It mostly hides the STDOUT. The only exception is when a server is running where output is useful.

The setup1() function checks if you already have a previous project directory and optionally removes it.

The setup2() function clones a git repo and changes to the branch specified as an argument to the script. The first argument of the script(the project name) is inserted into the git clone url(unless the all argument is used).

The setup3() function checks if you already have a web server running on port 8080 and if you have, gives you a choice to kill it.

The fail() function gets called if any step in any project fails. The first argument passed to the fail function is the error message and the second argument passed is the name of the function that failed. This is so we can print both of them out to STDERR.

The show-result() function simply displays the results of the installation of the projects. This only gets shown if there are errors or if you're running all the tests. This does *not* get called if you only run one test(this is what the setup_result variable is for).

The all() function gets called if you've decided to run all the tests. This runs through all the setups(setup1, setup2, and setup3) and then calls one of the projects. It does this for each and every project. Note that the setup_result variable has to be unset in order for it to be reused by the next project in the all function.

The rest of the functions in the script have to do with the steps from the PiT spreadsheet.
