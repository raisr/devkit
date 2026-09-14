# Replaces the content between a pair of devkit markers in a target file, or
# inserts the whole block when the markers are not there yet.
#
# Called with the target file as the only argument and two variables in the
# environment:
#   BLOCK_ID   marker id, e.g. devkit:core or devkit:stack/dotnet-core
#   BLOCK_SRC  path to the file whose content goes between the markers
#
# The markers are comment lines in every format that uses # for comments -
# .gitignore, .editorconfig, .gitattributes, shell.
#
# WHERE A NEW BLOCK GOES: directly after the last devkit block already in the
# file, and at the very top when there is none. Never at the end. Both formats
# this is used for resolve a conflict by taking the *later* line - an
# .editorconfig section overrides an earlier one, a .gitignore negation
# re-includes what an earlier line excluded - so a block appended at the bottom
# would silently override the project instead of the other way round. It also
# keeps `root = true` in the .editorconfig preamble, where it is the only place
# it means anything.

BEGIN {
    id      = ENVIRON["BLOCK_ID"]
    opening = "# >>> " id " >>>"
    closing = "# <<< " id " <<<"
}

{
    line[NR] = $0
    if ($0 == opening) { start = NR }
    if ($0 == closing) { end = NR }
    if ($0 ~ /^# <<< devkit:/) { last_close = NR }
}

END {
    if ((start > 0) != (end > 0) || (start > 0 && end < start)) {
        printf "devkit: %s has a broken %s block - one marker is missing or they are out of order.\n", \
            FILENAME, id > "/dev/stderr"
        printf "devkit: repair it by hand; rewriting it here would drop whatever sits between them.\n" \
            > "/dev/stderr"
        exit 1
    }

    if (start > 0) {                      # already there: replace in place
        for (i = 1; i < start; i++) print line[i]
        put()
        for (i = end + 1; i <= NR; i++) print line[i]
    } else if (NR == 0) {                 # empty or missing target
        put()
    } else if (last_close > 0) {          # after the last devkit block
        for (i = 1; i <= last_close; i++) print line[i]
        print ""
        put()
        for (i = last_close + 1; i <= NR; i++) print line[i]
    } else {                              # first block, project owns the file
        put()
        print ""
        for (i = 1; i <= NR; i++) print line[i]
    }
}

function put(   line) {
    print opening
    while ((getline line < ENVIRON["BLOCK_SRC"]) > 0) print line
    close(ENVIRON["BLOCK_SRC"])
    print closing
}
