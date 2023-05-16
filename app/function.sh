#!/usr/bin/env bash

function get_self_cid {
    local self_cid=""

    if [[ -f /proc/1/cpuset ]]; then
        self_cid="$(grep -Eo '[[:alnum:]]{64}' /proc/1/cpuset)"
    fi
    if [[ ( ${#self_cid} != 64 ) && ( -f /proc/self/cgroup ) ]]; then
        self_cid="$(grep -Eo -m 1 '[[:alnum:]]{64}' /proc/self/cgroup)"
    fi
    if [[ ( ${#self_cid} != 64 ) ]]; then
        self_cid="$(docker_api "/containers/$(hostname)/json" | jq -r '.Id')"
    fi

    if [[ ${#self_cid} == 64 ]]; then
        echo "$self_cid"
    else
        echo "Error: can't get my container ID" >&2
        return 1
    fi
}

function docker_api {
    local scheme
    local curl_opts=(-s)
    local method=${2:-GET}

    if [[ -n "${3:-}" ]]; then
        curl_opts+=(-d "$3")
    fi
    if [[ -z "$DOCKER_HOST" ]]; then
        echo "Error: DOCKER_HOST variable not set" >&2
        return 1
    fi
    if [[ $DOCKER_HOST == unix://* ]]; then
        curl_opts+=(--unix-socket "${DOCKER_HOST#unix://}")
        scheme='http://localhost'
    else
        scheme="http://${DOCKER_HOST#*://}"
    fi

    [[ $method = "POST" ]] && curl_opts+=(-H 'Content-Type: application/json')

    curl "${curl_opts[@]}" -X "${method}" "${scheme}$1"
}

function docker_exec {
    local id="${1?missing id}"
    local cmd="${2?missing command}"
    local data=$(printf '{ "AttachStdin": false, "AttachStdout": true, "AttachStderr": true, "Tty":false,"Cmd": %s }' "$cmd")

    exec_id=$(docker_api "/containers/$id/exec" "POST" "$data" | jq -r .Id)

    if [[ -n "$exec_id" && "$exec_id" != "null" ]]; then
        docker_api "/exec/${exec_id}/start" "POST" '{"Detach": false, "Tty":false}'
    else
        echo "Error: can't exec command ${cmd} in container ${id}." >&2
        echo "Check if the container is running." >&2
        return 1
    fi
}

function get_nginx_proxy_cid {
    local nginx_cid
    local volumes_from
    
    if [[ -n "${NGINX_PROXY_CONTAINER:-}" ]]; then
        nginx_cid="$NGINX_PROXY_CONTAINER"
    elif [[ $(get_self_cid) ]]; then
        volumes_from=$(docker_api "/containers/$(get_self_cid)/json" | jq -r '.HostConfig.VolumesFrom[]' 2>/dev/null)
        for cid in $volumes_from; do
            cid="${cid%:*}"
            if [[ $(docker_api "/containers/$cid/json" | jq -r '.Config.Env[]' | grep -c -E '^NGINX_VERSION=') = "1" ]]; then
                nginx_cid="$cid"
                break
            fi
        done
    fi

    [[ -n "$nginx_cid" ]] && echo "$nginx_cid"
}

function reload_nginx {
    local nginx_proxy_cid=$(get_nginx_proxy_cid)

    if [[ -n "${nginx_proxy_cid:-}" ]]; then
        echo "Reloading nginx proxy (${nginx_proxy_cid})..."
        docker_exec "${nginx_proxy_cid}" \
            '[ "sh", "-c", "/app/docker-entrypoint.sh /usr/local/bin/docker-gen /app/nginx.tmpl /etc/nginx/conf.d/default.conf; /usr/sbin/nginx -s reload" ]' \
            | sed -rn 's/^.*([0-9]{4}\/[0-9]{2}\/[0-9]{2}.*$)/\1/p'
        [[ ${PIPESTATUS[0]} -eq 1 ]] && echo "Error: can't reload nginx proxy." >&2
    fi
}
