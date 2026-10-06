#!/usr/bin/env bash
# GnomeLngSwitcher removal. Usage: bash uninstall.sh [--purge]
# Settings (~/.config/gnome-lng-switcher) are kept unless --purge is given.
gls_uninstall() (
    set -euo pipefail
    fail() { printf 'Uninstall failed: %s\n' "$*" >&2; exit 1; }
    app_id=io.github.OleksiyM.GnomeLngSwitcher
    uuid=gnome-lng-switcher@oleksiym.github.io
    app_dir=${GNOME_LNG_SWITCHER_APP_DIR:-"$HOME/Applications/GnomeLngSwitcher"}
    data_dir=${XDG_DATA_HOME:-"$HOME/.local/share"}
    config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}
    purge=no
    for arg in "$@"; do
        case "$arg" in
            --purge) purge=yes ;;
            -h|--help)
                printf '%s\n' 'Uninstall: bash uninstall.sh [--purge]' \
                    'Stops the daemon, disables the Shell extension and removes the app.' \
                    'Settings are kept unless --purge is supplied.'
                exit 0 ;;
            *) fail "Unknown option: $arg" ;;
        esac
    done
    printf '%s\n' '' '📦 GnomeLngSwitcher · uninstall' ''
    [[ $EUID -ne 0 ]] || fail 'Run as your desktop user, not with sudo.'
    for directory in "$app_dir" "$data_dir" "$config_dir"; do
        [[ $directory == /* && $directory != / ]] || fail 'Installation and XDG paths must be absolute, non-root paths.'
    done

    printf '🛑 Stopping the daemon…\n'
    pid_file="$config_dir/gnome-lng-switcher/daemon.pid"
    if [[ -f $pid_file ]]; then
        pid=$(cat "$pid_file" 2>/dev/null || true)
        if [[ $pid =~ ^[0-9]+$ ]] && grep -aq gnome-lng-switcher "/proc/$pid/cmdline" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f -- "$pid_file"
    fi
    pkill -f -- '/gnome-lng-switcher --daemon' 2>/dev/null || true
    systemctl --user stop gnome-lng-switcher 2>/dev/null || true

    printf '🧩 Disabling the Shell extension…\n'
    if command -v gnome-extensions >/dev/null; then
        gnome-extensions disable "$uuid" 2>/dev/null || true
        gnome-extensions disable gnome-lng-switcher@github.com 2>/dev/null || true
    fi

    printf '🗑️  Removing application and desktop integration…\n'
    rm -rf -- "$data_dir/gnome-shell/extensions/$uuid" \
        "$data_dir/gnome-shell/extensions/gnome-lng-switcher@github.com"
    rm -f -- "$data_dir/applications/$app_id.desktop" \
        "$config_dir/autostart/GnomeLngSwitcher.desktop" \
        "$app_dir/gnome-lng-switcher" "$app_dir/uninstall.sh"
    rmdir -- "$app_dir" 2>/dev/null || true
    # Legacy (pre-rename) location.
    rm -rf -- "$HOME/Applications/LngSwitcher"

    if [[ $purge == yes ]]; then
        printf '%s\n' '⚠️  Removing settings and logs.'
        rm -rf -- "$config_dir/gnome-lng-switcher"
    else
        printf '%s\n' '📝 Settings were kept (use --purge to remove them).'
    fi
    if command -v update-desktop-database >/dev/null; then update-desktop-database "$data_dir/applications" 2>/dev/null || true; fi
    printf '%s\n' '' '✅ GnomeLngSwitcher uninstalled.' \
        '💡 Log out and back in to unload cached Shell extension code.'
)
gls_uninstall "$@"
