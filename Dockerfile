FROM ubuntu:20.04 AS builder

ENV BUILD_DIR=/usr/local/src

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install tzdata \
    && apt-get install -y --no-install-recommends locales \
    && apt-get install -y --no-install-recommends git \
    && apt-get install -y --no-install-recommends scons \
    && apt-get install -y --no-install-recommends make \
    && apt-get install -y --no-install-recommends python3.8 \
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

# McPAT

WORKDIR $BUILD_DIR

COPY src/mcpat $BUILD_DIR/mcpat

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
               g++-multilib \
    && rm -rf /var/lib/apt/lists/* \
    && cd mcpat \
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
               libgmp-dev \
    && rm -rf /var/lib/apt/lists/* \
    && cd ./timeloop/src \
    && ln -s ../pat-public/src/pat . \
    && cd .. \
    # --d for debug purpose
    && scons --d --accelergy \
    && scons --d --static --accelergy \
    && cp build/timeloop-mapper  /usr/local/bin \
    && cp build/timeloop-metrics /usr/local/bin \
    && cp build/timeloop-model   /usr/local/bin

#
# Main image
#
FROM ubuntu:20.04

LABEL maintainer="timeloop-accelergy@mit.edu"

# Arguments
ARG BUILD_DATE
ARG VCS_REF
ARG BUILD_VERSION

# Labels
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.build-date=$BUILD_DATE
#LABEL org.label-schema.name="Accelergy-Project/accelergy-timeloop-infrastructure"
LABEL org.label-schema.name="Accelergy-Project/accelergy-timeloop-infrastructure-with-mcpat"
LABEL org.label-schema.description="Infrastructure setup for Timeloop/Accelergy tools"
LABEL org.label-schema.url="http://accelergy.mit.edu/"
LABEL org.label-schema.vcs-url="https://github.com/Accelergy-Project/accelergy-timeloop-infrastructure"
LABEL org.label-schema.vcs-ref=$VCS_REF
LABEL org.label-schema.vendor="Wu"
LABEL org.label-schema.version=$BUILD_VERSION
#LABEL org.label-schema.docker.cmd="docker run -it --rm -v ~/workspace:/home/workspace timeloopaccelergy/accelergy-timeloop-infrastructure"
LABEL org.label-schema.docker.cmd="docker run -it --rm -v ~/workspace:/home/workspace vi270662/accelergy-timeloop-infrastructure-with-mcpat"

ENV BIN_DIR=/usr/local/bin
ENV BUILD_DIR=/usr/local/src
ENV LIB_DIR=/usr/local/lib
ENV SHARE_DIR=/usr/local/share
ENV INCLUDE_DIR=/usr/local/include

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        git \
        wget \
        vim \
    && apt-get install -y --no-install-recommends python3-dev \
    && apt-get install -y --no-install-recommends python3-pip \
    && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install tzdata \
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
       cmake \
       ninja-build \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd workspace \
    && useradd -m -d /home/workspace -c "Workspace User Account" -s /usr/sbin/nologin -g workspace workspace \
    && if [ ! -d $BUILD_DIR ]; then mkdir $BUILD_DIR; fi

# For debug purpose
RUN apt-get update \
    && apt-get install -y --no-install-recommends gdb

# Get tools built in other containers

WORKDIR $BUILD_DIR

COPY --from=builder  $BUILD_DIR/timeloop/build/timeloop-mapper  $BIN_DIR
COPY --from=builder  $BUILD_DIR/timeloop/build/timeloop-metrics $BIN_DIR
COPY --from=builder  $BUILD_DIR/timeloop/build/timeloop-model   $BIN_DIR
COPY --from=builder  $BUILD_DIR/cacti/cacti $BIN_DIR
COPY --from=builder  $BUILD_DIR/mcpat/mcpat $BIN_DIR

# Get libraries and includes

WORKDIR $BUILD_DIR

COPY --from=builder  $BUILD_DIR/timeloop/lib/*.a   $LIB_DIR/
COPY --from=builder  $BUILD_DIR/timeloop/lib/*.so  $LIB_DIR/
COPY --from=builder  $BUILD_DIR/timeloop/include/* $INCLUDE_DIR/timeloop/

# Get all source

WORKDIR $BUILD_DIR

COPY src/ $BUILD_DIR/

#WORKDIR $BUILD_DIR
#RUN apt-get update \
#    && apt-get install -y --no-install-recommends locales \
#    && locale-gen en_US.UTF-8
#ENV LC_CTYPE en_US.UTF-8
#ENV LANG en_US.UTF-8
#RUN python3 -m pip install setuptools \
#    && cd terminal_markdown_viewer \
#    && python3 -m pip install .

# Accelergy

WORKDIR $BUILD_DIR

# Note source for accelergy was copied in above

COPY --from=builder  $BUILD_DIR/cacti $SHARE_DIR/accelergy/estimation_plug_ins/accelergy-cacti-plug-in/cacti
COPY --from=builder  $BUILD_DIR/mcpat $SHARE_DIR/accelergy/estimation_plug_ins/accelergy-mcpat-plug-in/mcpat

RUN python3 -m pip install setuptools \
    && python3 -m pip install wheel \
    && python3 -m pip install libconf \
    && python3 -m pip install numpy \
    && cd accelergy \
    && python3 -m pip install . \
    && cd .. \
    && cd accelergy-aladdin-plug-in \
    && python3 -m pip install . \
    && cd .. \
    && cd accelergy-cacti-plug-in \
    && python3 -m pip install . \
    && chmod 777 $SHARE_DIR/accelergy/estimation_plug_ins/accelergy-cacti-plug-in/cacti \
    && cd .. \
    && cd accelergy-mcpat-plug-in \
    && python3 -m pip install . \
    && chmod 777 $SHARE_DIR/accelergy/estimation_plug_ins/accelergy-mcpat-plug-in \
    && chmod 777 $SHARE_DIR/accelergy/estimation_plug_ins/accelergy-mcpat-plug-in/mcpat \
    && cd .. \
    && cd accelergy-table-based-plug-ins \
    && python3 -m pip install .

# Add conda and python3.8 (in conda)
# WARNING: Conda should be installed after Accelergy. Otherwise, some Accelergy
# data files are not installed correctly.
WORKDIR $BIN_DIR

# Errors with the latest version of Miniconda (the bash execution solution
# does not work either)
# An older version is used (see https://repo.continuum.io/miniconda/)
# ( SHELL ["/bin/bash", "-c"] )
#RUN wget -O ~/miniconda.sh https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh \
RUN wget -O ~/miniconda.sh https://repo.continuum.io/miniconda/Miniconda3-py39_4.12.0-Linux-x86_64.sh \
    && chmod +x ~/miniconda.sh \
    && ~/miniconda.sh -b -p $BIN_DIR/conda \
    && rm ~/miniconda.sh
# ( SHELL ["/bin/sh", "-c"] )

ENV PATH=$BIN_DIR/conda/bin:$PATH

RUN conda install -y python=3.8

# PyTimeloop

WORKDIR $BUILD_DIR

RUN cd timeloop/src \
    && ln -s ../pat-public/src/pat . \
    && cd ../../timeloop-python \
    && rm -rf build \
    && TIMELOOP_INCLUDE_PATH=$BUILD_DIR/timeloop/include \
       TIMELOOP_LIB_PATH=$LIB_DIR \
       python3 -m pip install -e .

# Set up entrypoint

COPY docker-entrypoint.sh $BIN_DIR
ENTRYPOINT ["bash", "docker-entrypoint.sh"]

WORKDIR /home/workspace
CMD ["bash"]

