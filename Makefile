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

USER    := timeloopaccelergy
REPO    := accelergy-timeloop-infrastructure

NAME    := ${USER}/${REPO}
TAG     := $$(git log -1 --pretty=%h)
IMG     := ${NAME}:${TAG}

ALTTAG  := latest
ALTIMG  := ${NAME}:${ALTTAG}

# For Timeloop installation
BARVINOK_VER ?= 0.41.6
NTL_VER      ?= 11.5.1

all:	build


# Pull all submodules

pull:
	# Only update top-level submodules
	GIT_MAX_RECURSION=1 git submodule update --remote --merge --recursive

	cp cacti.patch ./src/cacti/ && \
	cd ./src/cacti/ && \
	git reset --hard && \
	git apply cacti.patch

	cp cacti.patch ./src/accelergy-cacti-plug-in/cacti/ &&  \
	cd ./src/accelergy-cacti-plug-in/cacti/ && \
	git reset --hard && \
	git apply cacti.patch

# Build and tag docker image
build-amd64:
	"${DOCKER_EXE}" build ${BUILD_FLAGS} --platform linux/amd64 \
          --build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
          --build-arg VCS_REF=${TAG} \
          --build-arg BUILD_VERSION=${VERSION} \
          -t ${IMG}-amd64 .
	"${DOCKER_EXE}" tag ${IMG}-amd64 ${ALTIMG}-amd64

build-arm64:
	"${DOCKER_EXE}" build ${BUILD_FLAGS} --platform linux/arm64 \
          --build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
          --build-arg VCS_REF=${TAG} \
          --build-arg BUILD_VERSION=${VERSION} \
          -t ${IMG}-arm64 .
	"${DOCKER_EXE}" tag ${IMG}-arm64 ${ALTIMG}-arm64

# Push docker image

push-amd64:
	@echo "Pushing ${NAME}:${ALTTAG}-amd64"
	#Push Amd64 version 
	"${DOCKER_EXE}" push ${NAME}:${ALTTAG}-amd64
	#Combine Amd64 version into multi-architecture docker image.
	"${DOCKER_EXE}" manifest create \
		${NAME}:${ALTTAG} \
		--amend ${NAME}:${ALTTAG}-amd64 \
	  --amend ${NAME}:${ALTTAG}-arm64 
	"${DOCKER_EXE}" manifest push ${NAME}:${ALTTAG}



push-arm64:
	@echo "Pushing ${NAME}:${ALTTAG}-arm64"
	#Push Arm64 version 
	"${DOCKER_EXE}" push ${NAME}:${ALTTAG}-arm64
	#Combine Arm64 version into multi-architecture docker image.
	"${DOCKER_EXE}" manifest create \
		${NAME}:${ALTTAG} \
		--amend ${NAME}:${ALTTAG}-amd64 \
	  --amend ${NAME}:${ALTTAG}-arm64 
	"${DOCKER_EXE}" manifest push ${NAME}:${ALTTAG}
	
# Lint the Dockerfile

lint:
	"${DOCKER_EXE}" run --rm -i hadolint/hadolint < Dockerfile || true


# Login to docker hub

login:
	"${DOCKER_EXE}" login --username ${DOCKER_NAME} --password ${DOCKER_PASS}

install_accelergy:
	python3 -m pip install setuptools wheel libconf numpy joblib
	cd src/accelergy-cacti-plug-in && make
	cd src/accelergy-neurosim-plug-in && make
	cd src && pip3 install ./accelergy*

install_timeloop:
	mkdir -p /tmp/build-timeloop

	sudo apt-get update \
		&& sudo DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install tzdata \
		&& sudo apt-get install -y --no-install-recommends \
						locales \
						curl \
						git \
						wget \
						python3-dev \
						python3-pip \
						scons \
						make \
						autotools-dev \
						autoconf \
						automake \
						libtool \
		&& sudo apt-get install -y --no-install-recommends \
						g++ \
						cmake

	sudo apt-get update \
		&& sudo apt-get install -y --no-install-recommends \
						g++ \
						libconfig++-dev \
						libboost-dev \
						libboost-iostreams-dev \
						libboost-serialization-dev \
						libyaml-cpp-dev \
						libncurses5-dev \
						libtinfo-dev \
						libgpm-dev \
						libgmp-dev

	cd /tmp/build-timeloop \
		&& wget https://libntl.org/ntl-${NTL_VER}.tar.gz \
		&& tar -xvzf ntl-${NTL_VER}.tar.gz \
		&& cd ntl-${NTL_VER}/src \
		&& ./configure NTL_GMP_LIP=on SHARED=on \
		&& make \
		&& sudo make install

	cd /tmp/build-timeloop \
	    && wget https://barvinok.sourceforge.io/barvinok-${BARVINOK_VER}.tar.gz \
		&& tar -xvzf barvinok-${BARVINOK_VER}.tar.gz \
		&& cd barvinok-${BARVINOK_VER} \
		&& ./configure --enable-shared-barvinok \
		&& make \
		&& sudo make install

	cd src/timeloop \
		&& cp -r pat-public/src/pat src/pat  \
		&& scons -j4 --with-isl --static --accelergy
	cp src/timeloop/build/timeloop-mapper  ~/.local/bin/timeloop-mapper
	cp src/timeloop/build/timeloop-metrics ~/.local/bin/timeloop-metrics
	cp src/timeloop/build/timeloop-model ~/.local/bin/timeloop-model
