# Cleanup

## Overview

This script is used to clean up quotaed filesystems by deleting the oldest files first and iterating until the usage is less than the specified threshold percentage.
It must run as a user with privilege to remove files and directories from that filesystem, and it uses the quota of the user it is running as.

Its primary intended use case is to manage the Firefly shared workarea, which keeps overrunning its quota on data-int.lsst.cloud.

## Variable conventions

Variables local to functions (or mainstream script) are lowercase.
Anything used inside a function that comes from elsewhere is UPPERCASE.
The choice to stay (almost) POSIX and avoid bash-isms is intentional.

## Required environment variables

`$CLEANUP_THRESHOLD` and `$CLEANUP_MOUNTPOINT` must be set before execution.

`$CLEANUP_THRESHOLD` specifies the integer percentage at or above which this
 script will attempt to remove files.
 It must be between 1 and 99 inclusive.
 The percentage applies to both block and file quotas (the only place I've ever seen files run out before blocks is in mail directories).
`$CLEANUP_MOUNTPOINT` specifies where the filesystem to be cleaned is mounted.

## Optional environment variables

Set `$_TESTING` to nonempty to exercise the loop logic without removing anything.
Set `$DEBUG` to nonempty to trace execution.

## Testing

Two methods of testing are provided.
Both rely on files in `app/test`.

* A test suite can be run with `app/test/test_cleanup`.
* Alternatively, in a container environment, while running as root or equivalent, you can source `app/test/test.env`.
  This sets the necessary environment variables and renames `quota` to `quota.real` if `/usr/bin/quota` exists and `/usr/bin/quota.real` does not.
  Then you can run `cleanup` with a mocked `quota` that always returns a fixed size.
  This will destroy all files older than a minute in `/tmp`, so maybe don't run it on a system where you or anyone else is currently relying on data in `/tmp`.

## Required commands

The `cleanup` command depends on the following additional commands: `awk`, `command`, `dirname`, and `tail`.
For it to run in non-testing mode, the following additional commands are required: `find`, `grep`, `quota`, and `xargs`.
It also relies on `quota` correctly functioning for it to run and remove files, which is likely to involve having NFS utilities installed as well.
When testing, `quota` is mocked out, and the test mode does not use `find`, `grep`, or `xargs`.

`readlink` is used if present, so that the script can be installed via a symlink, but it is not required.
All of the required commands are POSIX Mandatory except `quota`.

`cleanup` invokes `quota` with `-w` (`--no-wrap`).
Without it, `quota` moves a long filesystem name onto its own line and omits it from the line carrying the values, which shifts the fields it parses.

## Output

In correct operation, `cleanup` is silent.
Any output is on `stderr` and indicates an error has occurred.

## Return codes

This script exits with return code 0 on success; both "we were not above quota so we did nothing" and removing files until under quota are successes.
It exits with return code 1 for incorrect setup, and with return code 2 for failure to clean the requested directory.

Return code 1 covers a missing or non-numeric `$CLEANUP_THRESHOLD`, a missing `$CLEANUP_MOUNTPOINT` or one that is not a directory, a missing required command, and any failure to read the quota.
That last case matters: if `quota` fails or returns something unparsable, the script cannot tell whether it is over threshold, so it fails rather than exiting 0 — a silent "success" that cleaned nothing would let the filesystem fill up unnoticed.

When testing, it exits with return code 0 if all the tests pass, and with return code 1 if any fail.
