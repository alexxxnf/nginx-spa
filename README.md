# nginx for SPA

This repo contains Docker image for [nginx](https://registry.hub.docker.com/_/nginx/)
optimized to serve static [SPA](https://en.wikipedia.org/wiki/Single-page_application) behind load balancer.

The target of this project is to have nginx with smallest possible RAM and HDD footprint.

## Usage
```
FROM alexxxnf/nginx-spa

COPY ./dist/ /etc/nginx/html/
```

## Available modules
TBD
