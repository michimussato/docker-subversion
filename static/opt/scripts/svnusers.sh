#!/bin/bash

# ========================================
#  Configuration
# ========================================
PROG=$(basename "$0")
SVN_ROOT="${SVN_BASE}"
REPOS=("azura/game" "azura/raw" "azura/engine")
MASTER_AUTHZ="${SVN_ROOT}/${REPOS[0]}/conf/authz"
SVN_SHELL="/usr/local/bin/svnonly"
SVN_GROUP="svnusers"

# Authz groups — these control per-path repo permissions (not system groups)
# They must match the [groups] section in the authz file
VALID_GROUPS=("dev" "art" "design" "production" "qa" "guest")

# ========================================
#  Usage
# ========================================
usage() {
    echo "Usage:"
    echo "  $PROG add <username> <authz_group> [key_file_or_string]"
    echo "  $PROG key <username> <key_file_or_string>"
    echo "  $PROG clearkeys <username>"
    echo "  $PROG remove <username>"
    echo "  $PROG list"
    echo ""
    echo "Authz groups: ${VALID_GROUPS[*]}"
    echo "  These control per-path SVN permissions (who can read/write what)."
    echo "  All users are also added to the '$SVN_GROUP' system group for filesystem access."
    echo ""
    echo "Key can be a file path OR the public key string directly:"
    echo "  $PROG add jduart dev /tmp/jduart.pub"
    echo "  $PROG add jduart dev \"ssh-ed25519 AAAA... jduart@pc\""
    echo "  $PROG key artist1 \"ssh-ed25519 AAAA... artist1@pc\""
    echo "  $PROG clearkeys jduart    # wipe all keys (compromised key)"
    echo ""
    echo "Examples:"
    echo "  $PROG add jduart dev"
    echo "  $PROG add artist1 art \"ssh-ed25519 AAAA... artist1@pc\""
    echo "  $PROG key artist1 /tmp/artist1.pub"
    echo "  $PROG clearkeys artist1"
    echo "  $PROG remove olduser"
    echo "  $PROG list"
    exit 1
}

# ========================================
#  Helpers
# ========================================
validate_group() {
    local group=$1
    for g in "${VALID_GROUPS[@]}"; do
        if [ "$g" == "$group" ]; then
            return 0
        fi
    done
    echo "[ERROR] Invalid group '$group'. Valid groups: ${VALID_GROUPS[*]}"
    exit 1
}

import_key() {
    local username=$1
    local key_input=$2

    if [ -z "$key_input" ]; then
        echo "[WARN] No key provided. Add manually to /home/$username/.ssh/authorized_keys"
        return
    fi

    # Check if it's a file or a key string
    if [ -f "$key_input" ]; then
        cat "$key_input" >> /home/$username/.ssh/authorized_keys
        echo "[OK] Key imported from file for $username"
    elif echo "$key_input" | grep -qE "^ssh-(ed25519|rsa|ecdsa|dss) "; then
        echo "$key_input" >> /home/$username/.ssh/authorized_keys
        echo "[OK] Key imported from string for $username"
    else
        echo "[ERROR] Invalid key: not a file and doesn't look like a public key"
        exit 1
    fi
}

setup_ssh() {
    local username=$1
    local key_input=$2

    mkdir -p /home/$username/.ssh
    chmod 700 /home/$username/.ssh
    touch /home/$username/.ssh/authorized_keys
    chmod 600 /home/$username/.ssh/authorized_keys
    chown -R $username:$username /home/$username/.ssh

    import_key "$username" "$key_input"
}

add_to_authz() {
    local username=$1
    local group=$2

    if ! [ -f "$MASTER_AUTHZ" ]; then
        echo "[ERROR] Authz file not found: $MASTER_AUTHZ"
        exit 1
    fi

    if grep -P "^${group}\s*=" "$MASTER_AUTHZ" | grep -qw "$username"; then
        echo "[OK] $username already in authz group '$group'"
    else
        if grep -qP "^${group}\s*=" "$MASTER_AUTHZ"; then
            local members
            members=$(grep -P "^${group}\s*=" "$MASTER_AUTHZ" | sed "s/^${group}\s*=\s*//" | sed 's/\s//g')
            if [ -z "$members" ]; then
                sed -i "s/^${group}\s*=.*/${group} = ${username}/" "$MASTER_AUTHZ"
            else
                sed -i "s/^${group}\s*=.*/${group} = ${members},${username}/" "$MASTER_AUTHZ"
            fi
            echo "[OK] Added $username to authz group '$group'"
        else
            echo "[ERROR] Group '$group' not found in authz file. Add it manually."
            exit 1
        fi
    fi

    sync_authz
}

remove_from_authz() {
    local username=$1

    if ! [ -f "$MASTER_AUTHZ" ]; then
        echo "[ERROR] Authz file not found: $MASTER_AUTHZ"
        exit 1
    fi

    sed -i -E "s/,${username}//g; s/${username},//g; s/=\s*${username}$/= /g" "$MASTER_AUTHZ"
    echo "[OK] Removed $username from all authz groups"

    sync_authz
}

sync_authz() {
    # Normalize: strip spaces around commas in group lines
    sed -i -E '/^\[groups\]/,/^\[/{/^[a-z]/s/\s*,\s*/,/g}' "$MASTER_AUTHZ"

    for repo in "${REPOS[@]}"; do
        local target="${SVN_ROOT}/${repo}/conf/authz"
        if [ "$target" != "$MASTER_AUTHZ" ]; then
            cp "$MASTER_AUTHZ" "$target"
        fi
    done
    chgrp -R $SVN_GROUP "$SVN_ROOT"
    echo "[OK] Authz synced across all repos"
}

list_users() {
    echo ""
    echo "=== SVN Users ==="
    echo ""
    if [ -f "$MASTER_AUTHZ" ]; then
        echo "Authz groups (per-path permissions):"
        echo "---"
        sed -n '/^\[groups\]/,/^\[/{ /^\[groups\]/d; /^\[/d; p; }' "$MASTER_AUTHZ"
        echo ""
    fi
    echo "System users in '$SVN_GROUP' group:"
    echo "---"
    getent group $SVN_GROUP | cut -d: -f4 | tr ',' '\n' | sort
    echo ""
}

# ========================================
#  Commands
# ========================================
cmd_add() {
    local username=$1
    local group=$2
    local key_input=$3

    validate_group "$group"

    if id "$username" &>/dev/null; then
        echo "[OK] System user $username already exists"
        usermod -aG $SVN_GROUP "$username"
    else
        useradd -m -s "$SVN_SHELL" -G $SVN_GROUP "$username"
        if [ $? -ne 0 ]; then
            echo "[ERROR] Failed to create user $username"
            exit 1
        fi
        echo "[OK] Created system user $username (shell: $SVN_SHELL)"
    fi

    setup_ssh "$username" "$key_input"
    add_to_authz "$username" "$group"

    echo ""
    echo "[DONE] User $username added to authz group '$group'"
    echo "  Checkout: svn+ssh://${username}@svn.memoriaworks.com/azura/game/trunk"
}

cmd_key() {
    local username=$1
    local key_input=$2

    if ! id "$username" &>/dev/null; then
        echo "[ERROR] User $username does not exist. Use 'add' first."
        exit 1
    fi

    setup_ssh "$username" "$key_input"
    echo "[DONE] Key updated for $username"
}

cmd_clearkeys() {
    local username=$1

    if ! id "$username" &>/dev/null; then
        echo "[ERROR] User $username does not exist"
        exit 1
    fi

    local keyfile="/home/$username/.ssh/authorized_keys"
    if [ -f "$keyfile" ]; then
        local count
        count=$(grep -cE "^ssh-" "$keyfile" 2>/dev/null || echo 0)
        > "$keyfile"
        chmod 600 "$keyfile"
        chown "$username:$username" "$keyfile"
        echo "[OK] Cleared $count key(s) for $username"
        echo "[WARN] User $username can no longer access SVN until a new key is added"
        echo "  Add new key: $PROG key $username <key>"
    else
        echo "[WARN] No authorized_keys file found for $username"
    fi
}

cmd_remove() {
    local username=$1

    remove_from_authz "$username"

    if id "$username" &>/dev/null; then
        usermod -L "$username"
        chsh -s /usr/sbin/nologin "$username"
        echo "[OK] User $username locked and shell disabled"
    fi

    echo "[DONE] User $username removed from SVN access"
}

# ========================================
#  Main
# ========================================
if [ $# -lt 1 ]; then
    usage
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Run as root (sudo)"
    exit 1
fi

ACTION=$1
shift

case $ACTION in
    add)
        if [ $# -lt 2 ]; then
            echo "[ERROR] Usage: $PROG add <username> <authz_group> [key_file_or_string]"
            exit 1
        fi
        cmd_add "$1" "$2" "$3"
        ;;
    key)
        if [ $# -lt 2 ]; then
            echo "[ERROR] Usage: $PROG key <username> <key_file_or_string>"
            exit 1
        fi
        cmd_key "$1" "$2"
        ;;
    clearkeys)
        if [ $# -lt 1 ]; then
            echo "[ERROR] Usage: $PROG clearkeys <username>"
            exit 1
        fi
        cmd_clearkeys "$1"
        ;;
    remove)
        if [ $# -lt 1 ]; then
            echo "[ERROR] Usage: $PROG remove <username>"
            exit 1
        fi
        cmd_remove "$1"
        ;;
    list)
        list_users
        ;;
    *)
        usage
        ;;
esac
