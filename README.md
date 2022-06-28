# [vaadin-starter-installer]

# Dependencies
- [Playwright](https://playwright.dev/docs/intro)

# How It Works
The script starts of by looking for the `--verbose` argument, checking if the user has entered at least the first three required arguments, and converts dashes to underscores(base-starter.. to base_stater).It then calls some functions before calling the corresponding project function.

## Functions

usage() : gets called if the user has not entered the required three arguments(shown in the --help menu).

help_func() : shows the help menu.

check_directory() : checks for pre-existing project directories of the same name.

kill_server() : takes a port number as an argument and searches for the opened port and then kills the running server.

check_code() : checks the HTTP return value of the server.

check_message() : check if the string that implies that the server launched correctly is in the output file.

fail() : gets called if there are any errors.

increment_fail() : gets incremented everytime a command returns non-zero.

check_fail() : display the number of times a command has returned a non-zero status in a project.

git_clone() : clone a repo. It uses the first argument passed to it as the name of the project in the URL.

check_os() : checks the OS that the user is using and stores it in SYSTEM.

check_server() : checks if the UI has loaded in the browser using Playwright.

turn_off_browser_startup() : disables the automatic browser startup that's built into skeleton-starter-flow-spring(we already have our own with Playwright).
