#!/usr/bin/env bash

load_env() {
    local env_file="${1:-.env}"

    if [ -f "$env_file" ]; then
        set -a
        source "$env_file"
        set +a
        echo "Loading environment variables..."
    else
        echo "$env_file not found."
        return 1
    fi
}
