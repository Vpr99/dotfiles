function load-env --description "Drain ~/.config/.env (1Password FIFO) into universal exported vars"
    set -l envfile "$HOME/.config/.env"
    if not test -e $envfile
        echo "load-env: $envfile not found" >&2
        return 1
    end

    set -l count 0
    while read -l line
        test -z "$line"; and continue
        string match -q '#*' -- $line; and continue
        set -l parts (string split -m 1 = -- $line)
        test (count $parts) -eq 2; or continue
        set -l key (string trim -- $parts[1])
        set -l val (string trim -c '"\'' -- $parts[2])
        set -Ux $key $val
        set count (math $count + 1)
    end < $envfile

    set -Ux __OP_ENV_LOADED_AT (date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "load-env: loaded $count vars (persisted in fish_variables)"
end
