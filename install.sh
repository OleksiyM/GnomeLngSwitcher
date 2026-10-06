#!/usr/bin/env bash
# GnomeLngSwitcher per-user install/update from a signed release archive.
#   bash install.sh [--version v1.0.0] [--require-provenance]
# The whole entry point lives in a function so `curl | bash` reads it fully first.
gls_install() (
    set -euo pipefail
    fail() { printf 'Install failed: %s\n' "$*" >&2; exit 1; }
    trap 'printf "Installation did not complete. See the error above; fix it and rerun.\n" >&2' ERR

    repo=OleksiyM/GnomeLngSwitcher
    app_id=io.github.OleksiyM.GnomeLngSwitcher
    uuid=gnome-lng-switcher@oleksiym.github.io
    app_dir=${GNOME_LNG_SWITCHER_APP_DIR:-"$HOME/Applications/GnomeLngSwitcher"}
    data_dir=${XDG_DATA_HOME:-"$HOME/.local/share"}
    config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}
    tag=''
    require_provenance=no
    while (($#)); do
        case "$1" in
            --version)
                [[ $# -ge 2 ]] || fail '--version needs a tag such as v1.0.0'
                tag=$2; shift 2 ;;
            --require-provenance) require_provenance=yes; shift ;;
            -h|--help)
                printf '%s\n' 'Install/update: bash install.sh [--version v1.0.0] [--require-provenance]' \
                    'Downloads the release archive, verifies SHA-256 (and provenance when gh is available),' \
                    'installs to ~/Applications/GnomeLngSwitcher (override: GNOME_LNG_SWITCHER_APP_DIR)' \
                    'and restarts the daemon. No sudo, no dependency installation.'
                exit 0 ;;
            *) fail "Unknown option: $1" ;;
        esac
    done

    printf '%s\n' '========================================================' \
        '  GnomeLngSwitcher (Installer / Updater)' \
        '========================================================'
    [[ $EUID -ne 0 ]] || fail 'Run as your desktop user, not with sudo.'
    for directory in "$app_dir" "$data_dir" "$config_dir"; do
        [[ $directory == /* && $directory != / ]] || fail 'Installation and XDG paths must be absolute, non-root paths.'
    done
    # shellcheck disable=SC1003  # the backslash and quotes are literal characters in the pattern
    case "$app_dir" in
        *['"$`%\']*|*'|'*|*'&'*|*$'\n'*|*$'\r'*) fail 'Installation path contains characters unsupported in desktop launchers.' ;;
    esac
    for tool in curl tar gzip sha256sum awk sed install mktemp uname; do
        command -v "$tool" >/dev/null || fail "Missing required command: $tool"
    done
    case "$(uname -m)" in
        x86_64) arch=x86_64 ;;
        aarch64|arm64) arch=aarch64 ;;
        *) fail 'Only x86_64 and aarch64 release archives are supported.' ;;
    esac

    download=(curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 300)
    if [[ -z "$tag" ]]; then
        latest=$("${download[@]}" --head --output /dev/null --write-out '%{url_effective}' "https://github.com/$repo/releases/latest")
        [[ $latest == "https://github.com/$repo/releases/tag/"* ]] || fail 'No stable release found.'
        tag=${latest##*/}
    fi
    [[ $tag =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || fail 'Expected a stable tag such as v1.0.0.'
    package="gnome-lng-switcher-${tag#v}-$arch"
    archive="$package.tar.gz"
    url="https://github.com/$repo/releases/download/$tag"
    temporary=$(mktemp -d /tmp/gnome-lng-switcher-install.XXXXXXXX)
    trap 'rm -rf -- "$temporary"' EXIT

    printf '\n📦 GnomeLngSwitcher %s · %s\n\n⬇️  Downloading release…\n' "$tag" "$arch"
    "${download[@]}" --output "$temporary/$archive" "$url/$archive"
    "${download[@]}" --output "$temporary/SHA256SUMS" "$url/SHA256SUMS"

    printf '\n🔒 Verifying SHA-256…\n'
    hash=$(awk -v name="$archive" '$2 == name || $2 == "*" name { print $1 }' "$temporary/SHA256SUMS")
    [[ $hash =~ ^[0-9a-fA-F]{64}$ ]] || fail 'Missing or duplicate archive checksum.'
    (cd "$temporary"; printf '%s  %s\n' "$hash" "$archive" | sha256sum --check --status -) || fail 'SHA-256 mismatch. Nothing installed.'
    printf '✅ SHA-256 verified.\n'

    # Probe capabilities, not gh's version string. gh is optional.
    verify=no
    if command -v gh >/dev/null && help=$(gh attestation verify --help 2>/dev/null); then
        verify=yes
        for option in --bundle --repo --signer-workflow --source-ref --cert-oidc-issuer --deny-self-hosted-runners --predicate-type; do
            [[ $help == *"$option"* ]] || verify=no
        done
    fi
    if [[ $verify == yes ]]; then
        printf '\n🛡️  Verifying release provenance…\n'
        "${download[@]}" --output "$temporary/$archive.sigstore.json" "$url/$archive.sigstore.json"
        gh attestation verify "$temporary/$archive" \
            --bundle "$temporary/$archive.sigstore.json" --repo "$repo" \
            --signer-workflow "$repo/.github/workflows/release.yml" --source-ref "refs/tags/$tag" \
            --cert-oidc-issuer https://token.actions.githubusercontent.com \
            --deny-self-hosted-runners --predicate-type https://slsa.dev/provenance/v1
        printf '✅ Provenance verified.\n'
    elif [[ $require_provenance == yes ]]; then
        fail '--require-provenance needs gh with the required attestation flags. Install or update gh from a trusted source.'
    else
        printf '%s\n' '' 'ℹ️  Provenance skipped: gh is missing or too old. SHA-256 integrity passed.' \
            'For signed verification, install/update gh and rerun with --require-provenance.'
    fi

    # Extract the verified release into staging, never into the live installation.
    tar -xzf "$temporary/$archive" --no-same-owner --no-same-permissions -C "$temporary"
    source_dir="$temporary/$package"
    for file in gnome-lng-switcher uninstall.sh extension/metadata.json extension/extension.js \
        extension/prefs.js "data/$app_id.desktop.in"; do
        [[ -f "$source_dir/$file" ]] || fail "Archive is missing $file. Nothing installed."
    done

    # Stop a running daemon so the binary can be replaced cleanly.
    pid_file="$config_dir/gnome-lng-switcher/daemon.pid"
    if [[ -f $pid_file ]]; then
        pid=$(cat "$pid_file" 2>/dev/null || true)
        if [[ $pid =~ ^[0-9]+$ ]] && grep -aq gnome-lng-switcher "/proc/$pid/cmdline" 2>/dev/null; then
            printf '\n🛑 Stopping the running daemon (PID %s)…\n' "$pid"
            kill "$pid" 2>/dev/null || true
            sleep 1
        fi
        rm -f -- "$pid_file"
    fi
    pkill -f -- '/gnome-lng-switcher --daemon' 2>/dev/null || true
    systemctl --user stop gnome-lng-switcher 2>/dev/null || true

    # Migrate pre-rename installs (old UUID and ~/Applications/LngSwitcher).
    legacy_ext="$data_dir/gnome-shell/extensions/gnome-lng-switcher@github.com"
    if [[ -d $legacy_ext ]]; then
        printf '🧹 Removing legacy extension…\n'
        if command -v gnome-extensions >/dev/null; then gnome-extensions disable gnome-lng-switcher@github.com 2>/dev/null || true; fi
        rm -rf -- "$legacy_ext"
    fi
    rm -rf -- "$HOME/Applications/LngSwitcher"
    autostart="$config_dir/autostart/GnomeLngSwitcher.desktop"
    if [[ -f $autostart ]] && grep -q 'Applications/LngSwitcher/' "$autostart"; then
        sed -i 's#Applications/LngSwitcher/#Applications/GnomeLngSwitcher/#' "$autostart"
    fi

    printf '\n🚀 Installing to %s…\n' "$app_dir"
    install -d "$app_dir" "$data_dir/applications" "$data_dir/gnome-shell/extensions" "$config_dir/gnome-lng-switcher"
    install -m 0755 "$source_dir/gnome-lng-switcher" "$app_dir/gnome-lng-switcher"
    install -m 0755 "$source_dir/uninstall.sh" "$app_dir/uninstall.sh"
    # Replace only the application-owned extension tree.
    rm -rf -- "$data_dir/gnome-shell/extensions/$uuid"
    cp -R "$source_dir/extension" "$data_dir/gnome-shell/extensions/$uuid"
    sed "s|@BINARY@|$app_dir/gnome-lng-switcher|g" "$source_dir/data/$app_id.desktop.in" > "$data_dir/applications/$app_id.desktop"
    chmod 0644 "$data_dir/applications/$app_id.desktop"
    if command -v update-desktop-database >/dev/null; then update-desktop-database "$data_dir/applications" 2>/dev/null || true; fi
    printf '✅ Installed %s.\n' "$tag"

    # shellcheck disable=SC2016  # $USER is intentionally printed literally as a hint
    if ! id -nG | tr ' ' '\n' | grep -qx input; then
        printf '%s\n' '' "⚠️  User '$USER' is not in the 'input' group." \
            '    To intercept Control keys without root, run:' \
            '      sudo usermod -aG input $USER' \
            '    and log out / log back in.'
    fi

    printf '\n🚀 Starting the daemon…\n'
    if command -v systemd-run >/dev/null && systemctl --user is-system-running >/dev/null 2>&1; then
        systemctl --user reset-failed gnome-lng-switcher 2>/dev/null || true
        systemd-run --user --unit=gnome-lng-switcher "$app_dir/gnome-lng-switcher" --daemon >/dev/null 2>&1 || true
    fi
    if ! pgrep -f -- '/gnome-lng-switcher --daemon' >/dev/null 2>&1; then
        nohup "$app_dir/gnome-lng-switcher" --daemon </dev/null >"$config_dir/gnome-lng-switcher/daemon.log" 2>&1 &
        disown 2>/dev/null || true
    fi
    sleep 1
    if pgrep -f -- '/gnome-lng-switcher --daemon' >/dev/null 2>&1; then
        printf '✅ Daemon is running.\n'
    else
        printf 'ℹ️  Daemon did not start; see %s/gnome-lng-switcher/daemon.log\n' "$config_dir"
    fi

    printf '%s\n' '' '💡 ONE MORE STEP — the Shell extension needs a fresh session:' \
        '   1. Log out and back in.' \
        '   2. Run: gnome-extensions enable gnome-lng-switcher@oleksiym.github.io' \
        '      (or enable it in the Extensions app).' \
        "   To remove everything later: bash $app_dir/uninstall.sh"
)
gls_install "$@"
