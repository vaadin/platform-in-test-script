# [vaadin-starter-installer]

# How To Use

`./vaadin-starter-installer project version branch`

Tip: `./vaadin-starter-installer all version branch` will test all the starters.

Note: Ctrl-C interrupts the server and continues the script.


# How The Installer Works

The installer takes three arguments: the name of the project(base-starter-flow-cdi, or all -- for testing all projects -- for example), the version that you want to test, and a branch.

The script works by first calling the main function with all the arguments, then calling different setupt functions with those arguments that were passed to main.

The script almost always only outputs "this compilation succeeded" messages and errors. It mostly hides the STDOUT. The only exception is when a server starts where output is useful.

setup1() checks if you already have a previous project directory and optionally removes it.

setup2() clones a git repo and changes to the branch specified as an argument to the script. The first argument of the script(the project name) is inserted into the git clone url(unless the all argument is used).

TODO : Finish the README

