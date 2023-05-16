FROM nginxproxy/docker-gen AS docker-gen
FROM alpine

ENV DOCKER_HOST=unix:///var/run/docker.sock
ENV SELFSIGNED_EXPIRY 365

RUN apk add --no-cache --virtual .bin-deps \
    bash \
    curl \
    jq \
    openssl

COPY --from=docker-gen /usr/local/bin/docker-gen /usr/local/bin/

COPY app /app/
WORKDIR /app

ENTRYPOINT [ "/bin/bash", "/app/entrypoint.sh" ]
CMD [ "/bin/bash", "/app/start.sh" ]
