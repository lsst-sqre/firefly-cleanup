# Helper functions.

# Initialize variables they use.
PCT_BLK_USED=0  # Set in get_quota_pct()
PCT_FIL_USED=0

# Now the functions.
get_quota_pct () {
    # First line identifies the user.
    # Second line names the columns.
    # After that the lines alternate, but we only have one mountpoint.
    #  Next line names the filesystem.
    #  The one after that has all the values.
    # Hence the very last line contains the values.

    set +e  # Disable exit on failure here.
    quota=$(${QUOTA} -w -f "${CLEANUP_MOUNTPOINT}" | tail -1)
    rc=$?
    set -e
    if [ "${rc}" -ne 0 ]; then
        # Quota didn't work.  Probably that's because no quota is set on
        #  the filesystem, because the mountpoint is wrong, or because
        #  you're using BSD quota rather than GNU and the -f option doesn't
        #  work.
        #
        # Thus, you can't really use this script to clean up a MacOS host,
        #  but you can develop there.
        #
        # We must NOT carry on here.  Without a usage figure we cannot tell
        #  whether we are over threshold, and leaving $PCT_* at their
        #  initial 0 would make the caller "succeed" without cleaning
        #  anything -- a silent no-op that monitoring reads as success
        #  while the filesystem fills up.
        printf "\"%s\" -w -f \"%s\" failed with rc=%d;" \
               "${QUOTA}" "${CLEANUP_MOUNTPOINT}" "${rc}" 1>&2
        printf " cannot determine quota usage.\n" 1>&2
        return 1
    fi
    if [ -z "${quota}" ]; then
        # Also not something we can interpret as "under threshold".
        printf "\"%s\" -w -f \"%s\" produced no output;" \
               "${QUOTA}" "${CLEANUP_MOUNTPOINT}" 1>&2
        printf " cannot determine quota usage.\n" 1>&2
        return 1
    fi
    # Field layout of the values line, verified against the format strings in
    #  GNU quota 4.09 ("%15s%8s %7s%8s%8s%8s %7s%8s%8s" for the header, and
    #  " %7s%c %6s %7s %7s" twice for the values):
    #
    #   filesystem, blocks used, blocks soft, blocks hard, [block grace],
    #               inodes used, inodes soft, inodes hard, [inode grace]
    #
    # The two grace columns are only occupied when that resource is over its
    #  soft limit, so field numbers counted from the left shift under load.
    #  Counting the inode fields from the RIGHT is stable in both cases,
    #  because a trailing empty grace column contributes no field.
    #
    # The '*' marking an over-soft figure is printed as a separate %c, so
    #  whitespace splitting usually drops it; strip non-digits anyway in case
    #  a future version prints it adjacent to the number.
    #
    # We compare against the HARD limit, since that is what stops writes.
    #
    # Note the caller passes -w (--no-wrap): without it quota puts a long
    #  filesystem name on its own line and omits it from the values line,
    #  which shifts the block fields by one and silently misreports usage.
    # A field that is empty after stripping non-digits was not a number at
    #  all, which means the layout isn't what we expect; that is a parse
    #  failure, and must be distinguished from a genuine limit of 0 (which
    #  means unlimited).
    PCT_BLK_USED=$(printf "%s\n" "${quota}" | \
                       awk '{ used = $2; limit = $4;
                              gsub(/[^0-9]/, "", used);
                              gsub(/[^0-9]/, "", limit);
                              if (used == "" || limit == "") { print "unparsable" }
                              else if (limit + 0 == 0) { print "unlimited" }
                              else { print int(100 * used / limit) } }')
    PCT_FIL_USED=$(printf "%s\n" "${quota}" | \
                       awk '{ used = $(NF-2); limit = $NF;
                              gsub(/[^0-9]/, "", used);
                              gsub(/[^0-9]/, "", limit);
                              if (used == "" || limit == "") { print "unparsable" }
                              else if (limit + 0 == 0) { print "unlimited" }
                              else { print int(100 * used / limit) } }')
    if [ "${PCT_BLK_USED}" = "unparsable" ] \
           || [ "${PCT_FIL_USED}" = "unparsable" ]; then
        printf "Could not parse quota output \"%s\"\n" "${quota}" 1>&2
        return 1
    fi
    # A zero limit means that resource is unlimited, so it can never be over
    #  threshold.  Report 0% rather than dividing by zero, which produced
    #  "+inf" and broke the caller's numeric comparison.
    if [ "${PCT_BLK_USED}" = "unlimited" ]; then
        PCT_BLK_USED=0
    fi
    if [ "${PCT_FIL_USED}" = "unlimited" ]; then
        PCT_FIL_USED=0
    fi
}

test_arithmetic () {
    # Test the awk arithmetic; specifically, round-towards zero
    if [ "${_TESTING}" -ne 1 ]; then
        return  # Return immediately unless we're testing.
    fi
    # Mock out the quota command.  The leading field is the filesystem name,
    #  as in real 'quota -w' output; without it every field is off by one and
    #  this test would validate a layout that cannot occur.
    #
    # It has to swallow the arguments get_quota_pct passes ('-w -f <mount>'),
    #  because we read the inode fields from the end of the line and appended
    #  arguments would shift them.
    quota_mock () {
        printf "%s\n" \
               "srv.example.com:/export 9840 10000 10000 6770 10000 10000"
    }
    QUOTA="quota_mock"
    get_quota_pct
    if [ "${PCT_BLK_USED}" -ne 98 ]; then
        # Note the doubled '%%': a bare '%' is eaten as a conversion
        #  specifier, which mangled the message and swallowed the value.
        printf "Expected 98%% blocks used, got %s%%\n" "${PCT_BLK_USED}" 1>&2
        exit 1
    fi
    if [ "${PCT_FIL_USED}" -ne 67 ]; then
        printf "Expected 67%% files used, got %s%%\n" "${PCT_FIL_USED}" 1>&2
        exit 1
    fi
}

test_failure () {
    # Test both failure modes
    if [ "${UNIT}" = "m" ]; then
        # Force PCT_FIL_USED above CLEANUP_THRESHOLD
        PCT_BLK_USED=30
        PCT_FIL_USED=95
        CLEANUP_THRESHOLD=80
    else
        # Force PCT_BLK_USED above CLEANUP_THRESHOLD
        PCT_BLK_USED=95
        PCT_FIL_USED=30
        CLEANUP_THRESHOLD=80
    fi
}
