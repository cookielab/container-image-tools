FROM alpine:3.21 as kaniko

RUN apk --update --no-cache add skopeo umoci curl

WORKDIR /workdir-kaniko

ARG KANIKO_VERSION

RUN skopeo copy docker://gcr.io/kaniko-project/executor:v${KANIKO_VERSION} oci:kaniko:current
RUN umoci unpack --image kaniko:current unpacked

FROM alpine:3.21 as credential_helpers

RUN apk --update --no-cache add unzip curl

WORKDIR /workdir

ARG TARGETARCH
ARG ENV_CRED_HELPER_VERSION
ARG ECR_CRED_HELRER_VERSION
ARG GCR_CRED_HELRER_VERSION

RUN curl -L https://github.com/isometry/docker-credential-env/releases/download/v${ENV_CRED_HELPER_VERSION}/docker-credential-env_${ENV_CRED_HELPER_VERSION}_linux_${TARGETARCH}.zip -o /workdir/docker-credential-env.zip
RUN unzip /workdir/docker-credential-env.zip
RUN chmod +x /workdir/docker-credential-env

RUN curl -L https://amazon-ecr-credential-helper-releases.s3.us-east-2.amazonaws.com/${ECR_CRED_HELRER_VERSION}/linux-${TARGETARCH}/docker-credential-ecr-login -o /workdir/docker-credential-ecr-login
RUN chmod +x /workdir/docker-credential-ecr-login

RUN curl -L https://github.com/GoogleCloudPlatform/docker-credential-gcr/releases/download/v${GCR_CRED_HELRER_VERSION}/docker-credential-gcr_linux_${TARGETARCH}-${GCR_CRED_HELRER_VERSION}.tar.gz -o /workdir/docker-credential-gcr.tar.gz
RUN tar -xf /workdir/docker-credential-gcr.tar.gz
RUN chmod +x /workdir/docker-credential-gcr

FROM alpine:3.21 as manifest_tool

RUN apk --update --no-cache add curl

WORKDIR /workdir

ARG TARGETARCH
ARG MANIFEST_TOOL_VERSION

RUN curl -L https://github.com/estesp/manifest-tool/releases/download/v${MANIFEST_TOOL_VERSION}/binaries-manifest-tool-${MANIFEST_TOOL_VERSION}.tar.gz -o /workdir/binaries-manifest-tool.tar.gz
RUN tar -xf /workdir/binaries-manifest-tool.tar.gz
RUN cp /workdir/manifest-tool-linux-$TARGETARCH /workdir/manifest-tool
RUN chmod +x /workdir/manifest-tool

FROM golang:1.24 AS skopeo

ARG SKOPEO_VERSION
ARG SKOPEO_DIR=/go/github.com/containers/skopeo

RUN apt update
RUN apt install -y go-md2man
RUN ln -s /usr/bin/go-md2man /go/bin/go-md2man

RUN mkdir -p $SKOPEO_DIR
RUN git clone --depth 1 --branch v${SKOPEO_VERSION} https://github.com/containers/skopeo.git $SKOPEO_DIR

WORKDIR $SKOPEO_DIR

ARG TARGETARCH

ENV GOARCH=$TARGETARCH
ENV CGO_ENABLED=0
ENV GOOS=linux

RUN make BUILDTAGS=containers_image_openpgp GO_DYN_FLAGS=

FROM alpine:3.21 AS intermediate

RUN mkdir -p /cit/.docker
COPY config.json /cit/.docker/config.json
RUN chmod 0644 /cit/.docker/config.json

RUN mkdir -p /cit/bin
COPY --from=kaniko /workdir-kaniko/unpacked/rootfs/kaniko/executor /cit/bin/kaniko
COPY --from=credential_helpers /workdir/docker-credential-env /cit/bin/docker-credential-env
COPY --from=credential_helpers /workdir/docker-credential-ecr-login /cit/bin/docker-credential-ecr-login
COPY --from=credential_helpers /workdir/docker-credential-gcr /cit/bin/docker-credential-gcr
COPY --from=manifest_tool /workdir/manifest-tool /cit/bin/manifest-tool
COPY --from=skopeo /go/github.com/containers/skopeo/bin/skopeo /cit/bin/skopeo

RUN apk --update --no-cache add ca-certificates
RUN mkdir -p /cit/ssl/certs
RUN cp /usr/share/ca-certificates/mozilla/* /cit/ssl/certs/

FROM scratch

COPY --from=busybox:1.37.0-musl /bin /busybox
# Declare /busybox as a volume to get it automatically in the path to ignore
VOLUME /busybox

COPY --from=intermediate /cit /container-image-tools
# Declare /container-image-tools as a volume to get it automatically in the path to ignore
VOLUME /container-image-tools

COPY --from=skopeo /go/github.com/containers/skopeo/default-policy.json /etc/containers/policy.json

ENV PATH /busybox:/container-image-tools/bin
ENV DOCKER_CONFIG /container-image-tools/.docker/
ENV SSL_CERT_DIR=/container-image-tools/ssl/certs
ENV HOME /root
ENV USER root

RUN ["/busybox/mkdir", "-p", "/bin"]
RUN ["/busybox/ln", "-s", "/busybox/sh", "/bin/sh"]

WORKDIR /workdir

CMD ["/bin/sh"]
