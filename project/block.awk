# Replaces the content between a pair of devkit markers in a target file, or
# appends the whole block when the markers are not there yet.
#
# Called with the target file as the only argument and two variables in the
# environment:
#   BLOCK_ID   marker id, e.g. devkit:core or devkit:stack/dotnet
#   BLOCK_SRC  path to the file whose content goes between the markers
#
# The markers are comment lines in every format that uses # for comments -
# .gitignore, .editorconfig, .gitattributes, shell.

BEGIN {
    id      = ENVIRON["BLOCK_ID"]
    opening = "# >>> " id " >>>"
    closing = "# <<< " id " <<<"
    inside  = 0
    seen    = 0
}

$0 == opening { inside = 1; seen = 1; print; emit(); next }
$0 == closing { inside = 0; print; next }
inside == 1   { next }
              { print }

END {
    if (seen == 0) {
        if (NR > 0) print ""
        print opening
        emit()
        print closing
    }
}

function emit(   line) {
    while ((getline line < ENVIRON["BLOCK_SRC"]) > 0) print line
    close(ENVIRON["BLOCK_SRC"])
}
