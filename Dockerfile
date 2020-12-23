FROM ubuntu:18.04 AS builder

ENV BUILD_DIR=/usr/local/src

RUN apt-get update \
    && apt-get install -y --no-install-recommends locales \
    && apt-get install -y --no-install-recommends git \
    && apt-get install -y --no-install-recommends scons \
    && apt-get install -y --no-install-recommends python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && if [ ! -d $BUILD_DIR ]; then mkdir $BUILD_DIR; fi

# Cacti

WORKDIR $BUILD_DIR

COPY src/cacti $BUILD_DIR/cacti

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
               g++ \
               libconfig++-dev \
    && rm -rf /var/lib/apt/lists/* \
    && cd cacti \
    && make \
    && chmod -R 777 .

# Build and install timeloop

WORKDIR $BUILD_DIR

COPY src/timeloop $BUILD_DIR/timeloop

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
               g++ \
               libconfig++-dev \
               libboost-dev \
               libboost-iostreams-dev \
               libboost-serialization-dev \
               libyaml-cpp-dev \
               libncurses5-dev \
               libtinfo-dev \
               libgpm-dev \
    && rm -rf /var/lib/apt/lists/* \
    && cd ./timeloop/src \
    && ln -s ../pat-public/src/pat . \
    && cd .. \
    && scons --static --accelergy \
    && cp build/timeloop-mapper  /usr/local/bin \
    && cp build/timeloop-metrics /usr/local/bin \
    && cp build/timeloop-model   /usr/local/bin

#
# Main image
#
FROM ubuntu:18.04

LABEL maintainer="timeloop-accelergy@mit.edu"

# Arguments
ARG BUILD_DATE
ARG VCS_REF
ARG BUILD_VERSION

# Labels
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.build-date=$BUILD_DATE
LABEL org.label-schema.name="Accelergy-Project/accelergy-timeloop-infrastructure"
LABEL org.label-schema.description="Infrastructure setup for Timeloop/Accelergy tools"
LABEL org.label-schema.url="http://accelergy.mit.edu/"
LABEL org.label-schema.vcs-url="https://github.com/Accelergy-Project/accelergy-timeloop-infrastructure"
LABEL org.label-schema.vcs-ref=$VCS_REF
LABEL org.label-schema.vendor="Wu"
LABEL org.label-schema.version=$BUILD_VERSION
LABEL org.label-schema.docker.cmd="docker run -it --rm -v ~/workspace:/home/workspace timeloopaccelergy/accelergy-timeloop-infrastructure"

ENV BIN_DIR=/usr/local/bin
ENV BUILD_DIR=/usr/local/src
ENV SHARE_DIR=/usr/local/share

RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && apt-get install -y --no-install-recommends python3-pip \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd workspace \
    && useradd -m -d /home/workspace -c "Workspace User Account" -s /usr/sbin/nologin -g workspace workspace \
    && if [ ! -d $BUILD_DIR ]; then mkdir $BUILD_DIR; fi

# Get tools built in other containers

WORKDIR $BUILD_DIR

COPY --from=builder  $BUILD_DIR/timeloop/build/timeloop-mapper  $BIN_DIR
COPY --from=builder  $BUILD_DIR/timeloop/build/timeloop-metrics $BIN_DIR
COPY --from=builder  $BUILD_DIR/timeloop/build/timeloop-model   $BIN_DIR
COPY --from=builder  $BUILD_DIR/cacti/cacti $BIN_DIR

# Get all source

WORKDIR $BUILD_DIR

COPY src/ $BUILD_DIR/

#WORKDIR $BUILD_DIR
#RUN apt-get update \
#    && apt-get install -y --no-install-recommends locales \
#    && locale-gen en_US.UTF-8
#ENV LC_CTYPE en_US.UTF-8
#ENV LANG en_US.UTF-8
#RUN pip3 install setuptools \
#    && cd terminal_markdown_viewer \
#    && pip3 install .

# Accelergy

WORKDIR $BUILD_DIR

# Note source for accelergy was copied in above

COPY --from=builder  $BUILD_DIR/cacti $SHARE_DIR/accelergy/estimation_plug_ins/accelergy-cacti-plug-in/cacti

RUN pip3 install setuptools \
    && pip3 install wheel \
    && pip3 install libconf \
    && pip3 install numpy \
    && cd accelergy \
    && pip3 install . \
    && cd .. \
    && cd accelergy-aladdin-plug-in \
    && pip3 install . \
    && cd .. \
    && cd accelergy-cacti-plug-in \
    && pip3 install . \
    && chmod 777 $SHARE_DIR/accelergy/estimation_plug_ins/accelergy-cacti-plug-in/cacti \
    && cd .. \
    && cd accelergy-table-based-plug-ins \
    && pip3 install .


# Set up entrypoint

COPY docker-entrypoint.sh $BIN_DIR
ENTRYPOINT ["docker-entrypoint.sh"]

WORKDIR /home/workspace
CMD ["bash"]
