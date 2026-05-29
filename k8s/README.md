# mac VICE Kubernetes Deployment

These manifests publish the static mac VICE website at:

- `http://macvice.com`
- `http://www.macvice.com`

They assume:

- an image named `ghcr.io/barryw/macvice-website`
- a Traefik ingress class named `traefik`

Add TLS settings to `k8s/ingress.yaml` after DNS and certificate management are
ready for the public hostnames.

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

```sh
kubectl apply -k k8s
kubectl -n macvice rollout status deployment/macvice-website
kubectl -n macvice get ingress macvice-website
```

Point DNS for `macvice.com` and `www.macvice.com` at the ingress controller's
external address. Add a TLS section once the public certificate path is in
place.

## Woodpecker

`.woodpecker/website.yaml` watches `website/**`, `k8s/**`, and its own pipeline
file on `macos/native-metal`.

On push it:

1. validates the HTML, JavaScript, screenshot script, and Kubernetes manifests
2. builds `ghcr.io/barryw/macvice-website:<short-sha>` with Kaniko
3. pushes the short-SHA tag and `latest`
4. applies `k8s/`
5. updates the deployment to the short-SHA image and waits for rollout

The Woodpecker Kubernetes backend must have:

- a `woodpecker-agent` service account with deploy permissions
- the existing `github_token` secret with permission to push to GHCR
- a `default/ghcr-secret` pull secret that can be copied into `macvice`
