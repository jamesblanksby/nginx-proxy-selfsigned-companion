#!/usr/bin/env bash

source /app/function.sh

function check_docker_socket {
    if [[ $DOCKER_HOST == unix://* ]]; then
        socket_file=${DOCKER_HOST#unix://}
        if [[ ! -S $socket_file ]]; then
            echo "Error: you need to share your Docker host socket with a volume at $socket_file." >&2
            echo "You should run your container with: '-v /var/run/docker.sock:$socket_file:ro'." >&2
            exit 1
        fi
    fi
}

function check_writable_directory {
    local dir="$1"
    if [[ $(get_self_cid) ]]; then
        if ! docker_api "/containers/$(get_self_cid)/json" | jq ".Mounts[].Destination" | grep -q "^\"$dir\"$"; then
            echo "Warning: '$dir' does not appear to be a mounted volume."
        fi
    else
        echo "Warning: can't check if '$dir' is a mounted volume without self container ID."
    fi
    if [[ ! -d "$dir" ]]; then
        echo "Error: can't access to '$dir' directory." >&2
        echo "Check that '$dir' directory is declared as a writable volume." >&2
        exit 1
    fi
    if ! touch "$dir/.checkwritable" 2>/dev/null ; then
        echo "Error: can't write to the '$dir' directory." >&2
        echo "Check that '$dir' directory is exported as a writable volume." >&2
        exit 1
    fi
    rm -f "$dir/.checkwritable"
}

function check_certificate_authority {
    local cn="nginx-proxy-selfsigned-companion"

    if [[ ! -f "/etc/nginx/certs/ca.crt" && ! -f "/etc/nginx/certs/ca.key" ]]; then
        echo "Generating certificate authority..."
        openssl genrsa -out "/etc/nginx/certs/ca.key" 2048
        openssl req -x509 \
            -newkey rsa:4096 -sha256 -nodes -days 3650 \
            -subj "/CN=$cn" \
            -keyout "/etc/nginx/certs/ca.key" \
            -out "/etc/nginx/certs/ca.crt"
    fi
}

if [[ "$*" == "/bin/bash /app/start.sh" ]]; then
    check_docker_socket
    if [[ -z "$(get_nginx_proxy_cid)" ]]; then
        echo "Error: can't get nginx-proxy container ID" >&2
        echo "Check that you are doing one of the following :" >&2
        echo -e "\t- Use the --volumes-from option to mount volumes from the nginx-proxy container." >&2
        echo -e "\t- Set the NGINX_PROXY_CONTAINER env var on the selfsigned-companion container to the name of the nginx-proxy container." >&2
        exit 1
    fi
    check_writable_directory "/etc/nginx/certs"
    check_certificate_authority
    reload_nginx
fi

exec "$@"
