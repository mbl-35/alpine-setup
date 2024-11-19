ARG ALPINE_VERSION="3.20"

FROM alpine:${ALPINE_VERSION}
ARG ALPINE_VERSION
ENV APORTS_PATH="/aports"

RUN apk add alpine-sdk build-base apk-tools alpine-conf busybox fakeroot \
    && apk add syslinux xorriso squashfs-tools sudo mtools dosfstools grub-efi \
    && git -c http.sslVerify=false clone \
        --branch v${ALPINE_VERSION} \
        --depth 1 https://git.alpinelinux.org/cgit/aports $APORTS_PATH \
    && abuild-keygen -i -a -n \
    && apk update

 COPY --chmod=700 docker-entrypoint.sh /.docker-entrypoint.sh
 ENTRYPOINT [ "/.docker-entrypoint.sh" ]
 CMD ["sh"]
