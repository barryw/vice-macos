# mac VICE Kubernetes Deployment

These manifests publish the static mac VICE website at:

- `http://macvice.com`
- `http://www.macvice.com`

They assume:

- an image named `ghcr.io/barryw/macvice-website`
- a Traefik ingress class named `traefik`

Add TLS settings to `deploy/ingress.yaml` after DNS and certificate management
are ready for the public hostnames.

## Build

Build the website container from the `website/` directory:

```sh
docker build -f website/Containerfile -t ghcr.io/barryw/macvice-website:latest website
docker push ghcr.io/barryw/macvice-website:latest
```

For a release tag:

```sh
docker build -f website/Containerfile -t ghcr.io/barryw/macvice-website:3.10.0-816fb9c-1 website
docker push ghcr.io/barryw/macvice-website:3.10.0-816fb9c-1
kustomize edit set image ghcr.io/barryw/macvice-website=ghcr.io/barryw/macvice-website:3.10.0-816fb9c-1
```

## Deploy

Create the namespace once before the pipeline deploys namespaced resources:

```sh
kubectl apply -f deploy/namespace.yaml
```

Then deploy the website resources:

```sh
kubectl apply -k deploy
kubectl -n macvice rollout status deployment/macvice-website
kubectl -n macvice get ingress macvice-website
```

Point DNS for `macvice.com` and `www.macvice.com` at the ingress controller's
external address. Add a TLS section once the public certificate path is in
place.

## Woodpecker

The site deploys via the **release-static-site** house template (Build &
Release Standard §5; WAL-32 / WAL-39 / WAL-48), referenced from
`.woodpecker/woodpecker-template.yaml`. The config service (woodpecker-release)
expands that ref into the full pipeline, which triggers on `website/**` and
`deploy/**` changes to `main`.

On push it:

1. builds `ghcr.io/barryw/macvice-website:build-<pipeline-number>` (and
   `:latest`) with Kaniko from `website/Containerfile`
2. ensures the `macvice` namespace + `ghcr-secret` exist, then `kubectl apply -k deploy`
3. updates the deployment to the build tag and waits for rollout
4. purges the Cloudflare cache for the zone

Release freshness needs no redeploy: `site.js` and the shared
`brand/js/download-latest.js` resolve the current GitHub Release client-side on
page load.

The Woodpecker Kubernetes backend must have:

- a service account with deploy permissions in the `macvice` namespace
- the `ghcr_username` / `ghcr_token` secrets with permission to push to GHCR
- the `cloudflare_api_token` + `cloudflare_zone_id` secrets for the cache purge
- a `default/ghcr-secret` pull secret that can be copied into `macvice`

The pipeline creates the `macvice` namespace if absent; cluster RBAC and the
pull secret are bootstrap tasks, not part of the app deploy.

> The former hand-maintained `.woodpecker/website.yaml` (which also ran the
> `validate-static` / `validate-k8s` / `wait-for-release` steps and watched
> `k8s/**`) was retired in favor of this template. The k8s manifests moved from
> `k8s/` to `deploy/` to match the template's trigger path and house layout.
