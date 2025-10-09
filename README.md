# cookielab/container-image-tools

This container image contains tools for building and managing container images.
Container is based on the official Buildah image with additional credential helpers and tools.

## Tools

- [buildah](https://github.com/containers/buildah/)
- [Manifest Tool](https://github.com/estesp/manifest-tool)
- [Skopeo](https://github.com/containers/skopeo)
- Credential Helpers
  - [ENV](https://github.com/isometry/docker-credential-env) for Docker Hub, GitLab Container Registry etc.
  - [AWS ECR](https://github.com/awslabs/amazon-ecr-credential-helper)
  - [Google Cloud GCR](https://github.com/GoogleCloudPlatform/docker-credential-gcr)

## Usage

Build container image and push it to GitLab Registry.

```shell
export DOCKER_registry_gitlab_com_USR="${CI_REGISTRY_USER}"
export DOCKER_registry_gitlab_com_PSW="${CI_REGISTRY_PASSWORD}"

# Build image with buildah
buildah build -t "${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHA}" .

# Push image to registry
buildah push "${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHA}"
```

As you can see we don't need to create any _docker config.json_ file. But we use power of Creds Helpers.
In this case ENV Cred Helper.

If you want to build multiarch images with buildah you need to build separate image on HW with that arch.
And then join them with manifest.

```yaml
include:
  - remote: https://raw.githubusercontent.com/cookielab/container-image-tools/main/.gitlab/multi-arch.yml

variables:
  DOCKER_registry_gitlab_com_USR: "${CI_REGISTRY_USER}"
  DOCKER_registry_gitlab_com_PSW: "${CI_REGISTRY_PASSWORD}"
  REGISTRY_IMAGE: "${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHA}"

build:
  extends: .multiarch
  script:
    - buildah build --build-arg TARGETARCH="${TARGETARCH}" -t "${REGISTRY_IMAGE}-${TARGETARCH}" .
    - buildah push "${REGISTRY_IMAGE}-${TARGETARCH}"

build-multiarch:
  extends: .manifest
  needs:
    - build
```

### GitLab CI/CD Example

Complete example for building and pushing container images with buildah:

```yaml
build:
  stage: build
  image: cookielab/container-image-tools:latest
  variables:
    DOCKER_registry_gitlab_com_USR: "${CI_REGISTRY_USER}"
    DOCKER_registry_gitlab_com_PSW: "${CI_REGISTRY_PASSWORD}"
  script:
    - buildah build -t "${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHA}" .
    - buildah push "${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHA}"
```
