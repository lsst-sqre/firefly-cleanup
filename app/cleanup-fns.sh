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
    quota=$(${QUOTA} -f ${CLEANUP_MOUNTPOINT} | tail -1)
    rc=$?
    set -e
    if [ "${rc}" -ne 0 ]; then
        # Quota didn't work.  Probably that's because no quota is set on
        #  the filesystem, or because you're using BSD find rather than
	#  GNU and the -f option doesn't work.
	#
	# Thus, you can't really use this script to clean up a MacOS host,
	#  but you can develop there.
        printf "\"%s\" rc=%d" ${QUOTA} ${rc} 2>&1
        printf "; assuming no quota for \"%s\"\n" "${CLEANUP_MOUNTPOINT}" 2>&1
        return
    fi
    if [ -z "${quota}" ]; then
        # Nothing to do.
        return
    fi
    # field 1: blocks used
    #       2: blocks allowed
    #       3: blocks grace (not considered)
    #       4: files used
    #       5: files allowed
    #       6: files grace (not considered)
    PCT_BLK_USED=$(printf "%s\n" "${quota}" | \
                       awk '{ print int(100 * $1 / $2)}')
    PCT_FIL_USED=$(printf "%s\n" "${quota}" | \
                       awk '{ print int(100 * $4 / $5)}')
}

test_arithmetic () {
    # Test the awk arithmetic; specifically, round-towards zero
    if [ "${_TESTING}" -ne 1 ]; then
        return  # Return immediately unless we're testing.
    fi
    # Mock out quota command
    QUOTA="echo 9840 10000 10000 6770 10000 10000"  # Simpler than printf here
    get_quota_pct
    if [ "${PCT_BLK_USED}" -ne 98 ]; then
        printf "Expected 98% blocks used, got %s%%\n" ${PCT_BLK_USED} 1>&2
        exit 1
    fi
    if [ "${PCT_FIL_USED}" -ne 67 ]; then
        printf "Expected 67% files used, got %s%%\n" ${PCT_FIL_USED} 1>&2
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
