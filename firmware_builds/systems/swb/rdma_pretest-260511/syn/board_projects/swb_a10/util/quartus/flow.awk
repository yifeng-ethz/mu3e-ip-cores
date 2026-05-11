#!/usr/bin/awk -f

# TODO:
# - remove message without id (code)
# - track message blocks

{
    # suppress similar messages
    s = gensub(/\[[0-9]+\]/, "[*]", "g", $0)
    if(last == s) {
        n += 1
        next
    }
    if(last != s && n > 0) {
        print "(" n " similar messages)"
        n = 0
        last = s
    }
    last = s

    s = $0
    # highlight info, warning, error messages
        s = gensub(/^(Info)/, "\033[32m\\1\033[0m", "g", s) # green
        s = gensub(/^(Warning)/, "\033[2;31m\\1\033[0m", "g", s) # dim red
        s = gensub(/^(Critical Warning)/, "\033[1;31m\\1\033[0m", "g", s) # dim red
        s = gensub(/^(Error|ERROR)/, "\033[1;31m\\1\033[0m", "g", s) # bold red

    print s
    fflush(stdout)
}
