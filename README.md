# mk.bash

a tiny library for creating make-like scripts with subcommands

To use it, create a command file called "mk" in the directory you want.
The directory should be where you want to run the command with "./mk".
The command file must source this file.
It must also define a usage message in $Usage,
and the program name in $Prog.

Subcommands are any function that is defined capitalized in the command file.
You may, of course, define other functions as well,
but they should not be capitalized unless you want a user to call them.
Users do not have to call subcommands with capitalization;
subcommands are capitalized automatically before calling their function.

You must let mk.bash process arguments before you do with the line:

```bash
Args=( "$@" ); processArgs; set -- "${Args[@]}"; unset -v Args
```

Finally, call main "$@" and your script is ready to run.

Some variables are made available to your script (don't redefine
these unless you know what you're doing):

-   Tab -- a tab character
-   Nl -- a newline character
-   IFS -- set to newline

This library disables word-splitting (by setting IFS to newline) and
globbing so you can reference any variables that
don't contain newlines (i.e. most variables with known values)
without the need for double-quotes.

See example/mk for a sample script using mk.bash.  You can run it with
the command:

```bash
MKDIR=.. ./mk --help
```
