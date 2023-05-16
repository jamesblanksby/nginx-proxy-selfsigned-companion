# selfsigned-companion

**selfsigned-companion** is a lightweight certificate companion container for [**nginx-proxy**](https://github.com/nginx-proxy/nginx-proxy) heavily inspired by [**acme-companion**](https://github.com/nginx-proxy/acme-companion).

> **Warning**  
> The certificates generated using this container should only be used for locally hosted projects.

### Features
* Automated creation of self-signed certificates using [**openssl**](https://github.com/openssl/openssl).
* Startup creation of a certificate authority (CA) to trust your self-signed certificates.
* Automated update and reload of nginx config on certificate creation.
* Configurable certificate [validaity period](#certificate-expiry).

## Basic usage (with the nginx-proxy container)

A writable volume must be declared on the **nginx-proxy** container so that it can be shared with the **selfsigned-companion** container:

* `/etc/nginx/certs` to store certificates and private keys (readonly for the **nginx-proxy** container).

Example of use:

### Step 1 - nginx-proxy

Start **nginx-proxy** with the two additional volumes declared:

```shell
$ docker run --detach \
    --name nginx-proxy \
    --publish 80:80 \
    --publish 443:443 \
    --volume certs:/etc/nginx/certs \
    --volume /var/run/docker.sock:/tmp/docker.sock:ro \
    nginxproxy/nginx-proxy
```

Binding the host docker socket (`/var/run/docker.sock`) inside the container to `/tmp/docker.sock` is a requirement of **nginx-proxy**.

### Step 2 - selfsigned-companion

Start **selfsigned-companion**, getting the volumes from **nginx-proxy** with `--volumes-from`:

```shell
$ docker run --detach \
    --name nginx-proxy-selfsigned \
    --volumes-from nginx-proxy \
    --volume /var/run/docker.sock:/var/run/docker.sock:ro \
    thisismyengine/nginx-proxy-selfsigned-companion
```

The host docker socket has to be bound inside this container too, this time to `/var/run/docker.sock`.

### Step 3 - proxied container(s)

Once both **nginx-proxy** and **selfsigned-companion** containers are up and running, start any container you want proxied with environment variables `VIRTUAL_HOST` and `SELFSIGNED_HOST` both set to the domain(s) your proxied container is going to use.

Certificates will only be issued for containers that have both `VIRTUAL_HOST` and `SELFSIGNED_HOST` variables set to domain(s) that correctly resolve to the host.

```shell
$ docker run --detach \
    --name proxied-app \
    --env "VIRTUAL_HOST=local.example.com" \
    --env "SELFSIGNED_HOST=local.example.com" \
    nginx
```

> **Note**  
> In this example `SELFSIGNED_HOST` covers all subdomains (`*.local.example.com`) so including all your FQDNs is not required.

The containers being proxied must expose the port to be proxied, either by using the `EXPOSE` directive in their Dockerfile or by using the `--expose` flag to `docker run` or `docker create`.

If the proxied container listens on and exposes another port other than the default `80`, you can force **nginx-proxy** to use this port with the [`VIRTUAL_PORT`](https://github.com/nginx-proxy/nginx-proxy#virtual-ports) environment variable.

Repeat [Step 3](#step-3---proxied-containers) for any other container you want to proxy.

## Getting nginx-proxy container IDs

For **selfsigned-companion** to work properly, it needs to know the ID of the nginx-proxy container.

There are two methods to inform the **selfsigned-companion** container of the nginx-proxy container ID:
* `environment variable`: assign a fixed name to the **nginx-proxy** container with `--name` and set the environment variable `NGINX_PROXY_CONTAINER` to this name on the **selfsigned-companion** container.
* `volumes-from`: Using this method, the **selfsigned-companion** container will get the **nginx-proxy** container ID from the volumes it got using the `volumes-from` option.

### `environment variable` method

```shell
$ docker run --detach \
    --name nginx-proxy-selfsigned \
    [...]
    --env "NGINX_PROXY_CONTAINER=unique-nginx-proxy" \
    thisismyengine/nginx-proxy-selfsigned-companion
```

> **Note**  
> The environment variable `NGINX_PROXY_CONTAINER` defaults to `nginx-proxy` so only include if your **nginx-proxy** container is named differently. 

### `volumes-from` method

```shell
$ docker run --detach \
    --name nginx-proxy-selfsigned \
    [...]
    --volumes-from nginx-proxy \
    thisismyengine/nginx-proxy-selfsigned-companion
```

## Certificate expiry

You may wish to alter the default `365` day self-signed certificate validity period, use the docker environment variable `SELFSIGNED_EXPIRY` on startup.

An example of a 10 year (`3650` day) validity period:

```shell
$ docker run --detach \
    --name proxied-app \
    [...]
    --env "SELFSIGNED_EXPIRY=3650"
    nginx
```
