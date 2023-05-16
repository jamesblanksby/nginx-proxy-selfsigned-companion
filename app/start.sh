#!/usr/bin/env bash

docker-gen -only-exposed -watch -notify-output -notify "/app/selfsigned_service" /app/selfsigned_service_data.tmpl /tmp/selfsigned_service_data
