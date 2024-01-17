#!/bin/sh -e


[ -z $MACHINE ] && (echo "ERROR: MACHINE= must be set"; exit 1)
[ -z $VERSION ] && (echo "ERROR: VERSION= required"; exit 1)
CREDS=${CREDS-"./credentials.zip"}
[ -f $CREDS ] || (echo "ERROR: $CREDS does not exist"; exit 1)

set -x

OSTREE_DIR=${OSTREE_DIR-"./deploy/images/${MACHINE}/ostree_repo/"}
REF=${REF-$(cat $OSTREE_DIR/refs/heads/*)}
PATH="${PATH}:./tmp-lmp/work/$(echo ${MACHINE} | tr '-' '_')-lmp-linux/lmp-factory-image/1.0-r0/recipe-sysroot-native/usr/bin/"

garage-push -j ${CREDS} -C ${OSTREE_DIR} -r ${REF}

garage-sign init --repo otace -c ${CREDS}
garage-sign targets pull --repo otace

garage-sign targets add --repo otace \
    --name lmp-$VERSION \
    --version $VERSION \
    --length 0 \
    --format ostree \
    --sha256 $REF \
    --hardwareids $MACHINE

garage-sign targets sign --repo otace --key-name targets
garage-sign targets push --repo otace
