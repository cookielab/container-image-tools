# cookielab/container-image-tools

This container image contains tools for building and managing container images.
Container is based on scratch but contains minimal shell tools from busybox.

## Tools

- [Busybox](https://hub.docker.com/_/busybox?tab=description)
- [buildah](https://github.com/containers/buildah/)
- [Manifest Tool](https://github.com/estesp/manifest-tool)
- [Skopeo](https://github.com/containers/skopeo)
- Credential Helpers
  - [ENV](https://github.com/isometry/docker-credential-env) for Docker Hub, GitLab Container Registry etc.
  - [AWS ECR](https://github.com/awslabs/amazon-ecr-credential-helper)
  - [Google Clous GCR](https://github.com/GoogleCloudPlatform/docker-credential-gcr)

## Usage

Build container image and push it to GitLab Registru.

```shell
export DOCKER_registry_gitlab_com_USR="${CI_REGISTRY_USER}"
export DOCKER_registry_gitlab_com_PSW="${CI_REGISTRY_PASSWORD}"
# TODO: buildah example
```

As you can see we don't need to create any _docker config.json_ file. But wes use power of Creds Helpers.
In this case ENV Cred Helper.

If you want to build multiarch images with kaniko you need to build separate image on HW with that arch.
And than join them with manifest.

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
    # TODO: replace with buildah example
    - kaniko --build-arg TARGETARCH="${TARGETARCH}" --destination "${REGISTRY_IMAGE}-${TARGETARCH}"

build-multiarch:
  extends: .manifest
  needs:
    - build
```
