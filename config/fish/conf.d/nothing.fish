# Nothing rice. Sourced before ~/.config/fish/config.fish, so your
# personal aliases still win if you redefine them there.
if not status is-interactive
    exit
end

set -g fish_greeting

if test "$TERM" != linux; and command -q starship
    if not set -q STARSHIP_SESSION_KEY
        function starship_transient_prompt_func
            starship module character
        end
        starship init fish | source
        if functions -q enable_transience
            enable_transience
        end
    end
end

# Kitty's default clear leaves the scrollback; this wipes it.
alias clear "printf '\033[2J\033[3J\033[1;1H'"
alias celar clear
alias claer clear
alias pamcan pacman

if command -q eza; and test "$TERM" != linux
    alias ls 'eza --icons=auto'
end

if test "$TERM" = xterm-kitty
    alias ssh 'kitten ssh'
end

if command -q qs
    alias q 'qs -p ~/.config/quickshell/nothing'
end

if command -q fastfetch
    alias neofetch fastfetch
end
