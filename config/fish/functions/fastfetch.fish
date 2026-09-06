# fastfetch, with the logo rotated when more than one is set.
#
# fastfetch has no hook of its own: it loads exactly one config file and
# draws whatever logo that file names, so alternating cannot live in the
# config. It has to be decided per run, here, and passed as flags.
#
# ~/.config/fastfetch/logo holds the names on one line, space separated.
# One name means the config already says it and this does nothing but
# call the binary, which is why the file is harmless to install.
#
#   scripts/fetch-logo.sh arch                 pin one
#   scripts/fetch-logo.sh alternate arch tamaki   take turns
function fastfetch --wraps fastfetch --description "fastfetch, rotating the logo when several are set"
    set -l ff ~/.config/fastfetch
    set -l names (cat $ff/logo 2>/dev/null | string split -n ' ')
    set -l n (count $names)

    if test $n -lt 2
        command fastfetch $argv
        return
    end

    # Which one is next. Kept out of the config so a run does not rewrite
    # a file you may be editing, and out of $ff so it is state, not
    # configuration.
    set -l state ~/.local/state/nothing
    mkdir -p $state
    set -l i (cat $state/fetch-logo 2>/dev/null | string trim)
    string match -qr '^[0-9]+$' -- "$i"; or set i 0
    set -l pick $names[(math "$i % $n + 1")]
    echo (math "($i + 1) % $n") >$state/fetch-logo

    switch $pick
        case tamaki
            # A picture needs a box in both directions: given only a
            # height, fastfetch reserves too few columns and draws it
            # over the first column of text.
            if test -s $ff/pngs/tamaki.png
                command fastfetch --logo-type kitty-direct \
                    --logo $ff/pngs/tamaki.png --logo-width 36 --logo-height 17 $argv
                return
            end
        case '*'
            if test -s $ff/logos/$pick.txt
                command fastfetch --logo-type file --logo $ff/logos/$pick.txt $argv
                return
            end
    end
    # Named a logo that is not there: better the config's own than nothing.
    command fastfetch $argv
end
