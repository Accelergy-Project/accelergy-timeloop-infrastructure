#
# Utility Makefile to build/push Docker images
#
# To use an alternate tag invoke as:
#
#   make build ALTTAG=<alternate-tag>
#
# Optionally override
#
#   DOCKER_EXE=<name of docker executable>
#   DOCKER_NAME=<name of user used to push the image>
#
# Set this envirnment or command line variable
#
#   DOCKER_PASS=<password of user used to push the image>
#
DOCKER_EXE ?= docker
DOCKER_NAME ?= timeloopaccelergy

VERSION := 0.2

#USER    := timeloopaccelergy
USER    := vi270662
#REPO    := accelergy-timeloop-infrastructure
REPO    := accelergy-timeloop-infrastructure-with-mcpat

NAME    := ${USER}/${REPO}
TAG     := $$(git log -1 --pretty=%h)
IMG     := ${NAME}:${TAG}

ALTTAG  := latest
ALTIMG  := ${NAME}:${ALTTAG}


all:	build


# Pull all submodules

pull:
	git submodule foreach git pull origin master


# Build and tag docker image

build:
	"${DOCKER_EXE}" build ${BUILD_FLAGS} \
          --build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
          --build-arg VCS_REF=${TAG} \
          --build-arg BUILD_VERSION=${VERSION} \
          -t ${IMG} .
	"${DOCKER_EXE}" tag ${IMG} ${ALTIMG}


# Push docker image

push:
	@echo "Pushing ${NAME}:${ALTTAG}"
	"${DOCKER_EXE}" push ${NAME}:${ALTTAG}


# Lint the Dockerfile

lint:
	"${DOCKER_EXE}" run --rm -i hadolint/hadolint < Dockerfile || true


# Login to docker hub

login:
	"${DOCKER_EXE}" login --username ${DOCKER_NAME} --password ${DOCKER_PASS}

