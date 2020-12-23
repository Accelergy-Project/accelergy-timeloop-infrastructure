#
# Ultility Makefile to build/push Docker images
#
#
# Set the following environment variables before invoking make:
#
#   DOCKER_EXE=<name of docker executable>
#   DOCKER_NAME=<name of user where image will be pushed>
#   DOCKER_PASS=<password of uesr where image will be pushed>
#
VERSION := 0.2

USER    := timeloopaccelergy
REPO    := accelergy-timeloop-infrastructure

NAME    := ${USER}/${REPO}
TAG     := $$(git log -1 --pretty=%h)
IMG     := ${NAME}:${TAG}
LATEST  := ${NAME}:latest


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
	"${DOCKER_EXE}" tag ${IMG} ${LATEST}
 

# Push docker image

push:
	@echo "Pushing ${NAME}"
	"${DOCKER_EXE}" push ${NAME}
 

# Lint the Dockerfile

lint:
	"${DOCKER_EXE}" run --rm -i hadolint/hadolint < Dockerfile || true


# Login to docker hub

login:
	"${DOCKER_EXE}" login --username ${DOCKER_NAME} --password ${DOCKER_PASS}

