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
    && apt-get install -y --no-install-recommends doxygen \
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


# NeuroSim
WORKDIR $BUILD_DIR
COPY src/accelergy-neurosim-plug-in $BUILD_DIR/accelergy-neurosim-plug-in
RUN cd accelergy-neurosim-plug-in \
    && mkdir NeuroSim \
    && cp -r DNN_NeuroSim_V1.3/Inference_pytorch/NeuroSIM/* ./NeuroSim/ \
    && cp -rf drop_in/* ./NeuroSim/ \
    && cd NeuroSim \
    && make \
    && chmod -R 777 .

# Build and install timeloop

WORKDIR $BUILD_DIR

COPY src/timeloop $BUILD_DIR/timeloop

ENV BARVINOK_VER=0.41.6
ENV NTL_VER=11.5.1

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install tzdata \
    && apt-get install -y --no-install-recommends \
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
    && apt-get install -y --no-install-recommends \
                       g++ \
                       cmake

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
    && rm -rf /var/lib/apt/lists/*

WORKDIR $BUILD_DIR
RUN wget https://libntl.org/ntl-$NTL_VER.tar.gz \
    && tar -xvzf ntl-$NTL_VER.tar.gz \
    && cd ntl-$NTL_VER/src \
    && ./configure NTL_GMP_LIP=on SHARED=on NATIVE=off \
    && make \
    && make install

WORKDIR $BUILD_DIR
RUN wget https://barvinok.sourceforge.io/barvinok-$BARVINOK_VER.tar.gz \
    && tar -xvzf barvinok-$BARVINOK_VER.tar.gz \
    && cd barvinok-$BARVINOK_VER \
    && ./configure --enable-shared-barvinok \
    && make \
    && make install

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
               scons \
               libconfig++-dev \
               libboost-all-dev \
               libboost-dev \
               libboost-iostreams-dev \
               libboost-serialization-dev \
               libyaml-cpp-dev \
               libncurses-dev \
               libtinfo-dev \
               libgpm-dev \
               git \
               build-essential \
               python3-pip

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
    && scons --accelergy -j 4 \
    && scons --static --accelergy -j 4 \
    && cp build/timeloop-mapper  /usr/local/bin \
    && cp build/timeloop-metrics /usr/local/bin \
    && cp build/timeloop-model   /usr/local/bin

WORKDIR $BUILD_DIR

RUN cd ./timeloop \
    && doxygen .doxygen-config

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

# Get tools built in other containers

WORKDIR $BUILD_DIR

COPY --from=builder  $BUILD_DIR/timeloop/build/timeloop-mapper  $BIN_DIR
COPY --from=builder  $BUILD_DIR/timeloop/build/timeloop-metrics $BIN_DIR
COPY --from=builder  $BUILD_DIR/timeloop/build/timeloop-model   $BIN_DIR

COPY --from=builder  $BUILD_DIR/cacti/cacti $BIN_DIR

# Get libraries and includes

WORKDIR $BUILD_DIR

COPY --from=builder  $BUILD_DIR/timeloop/lib/*.a   $LIB_DIR/
COPY --from=builder  $BUILD_DIR/timeloop/lib/*.so  $LIB_DIR/
COPY --from=builder  $BUILD_DIR/timeloop/include/* $INCLUDE_DIR/timeloop/

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install tzdata \
    && apt-get install -y --no-install-recommends \
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
                       graphviz \
    && apt-get install -y --no-install-recommends \
                       g++ \
                       cmake

# Get all source

WORKDIR $BUILD_DIR

COPY src/ $BUILD_DIR/

WORKDIR $BUILD_DIR
RUN echo "YES" | python3 $BUILD_DIR/timeloop/scripts/hyphens2underscores.py $BUILD_DIR/timeloop-python

#WORKDIR $BUILD_DIR
#RUN apt-get update \
#    && apt-get install -y --no-install-recommends locales \
#    && locale-gen en_US.UTF-8
#ENV LC_CTYPE en_US.UTF-8
#ENV LANG en_US.UTF-8
#RUN python3 -m pip install setuptools \
#    && cd terminal_markdown_viewer \
#    && python3 -m pip install .

# Get Timeloop documentation

COPY --from=builder $BUILD_DIR/timeloop/docs $BUILD_DIR/timeloop

# Accelergy

WORKDIR $BUILD_DIR

# Note source for accelergy was copied in above
RUN mkdir $BUILD_DIR/accelergy-neurosim-plug-in/NeuroSim
COPY --from=builder  $BUILD_DIR/accelergy-neurosim-plug-in/NeuroSim/main $BUILD_DIR/accelergy-neurosim-plug-in/NeuroSim/main

WORKDIR $BUILD_DIR

# accelergy-neurosim-main $BUILD_DIR/accelergy-neurosim-main

RUN python3 -m pip install setuptools \
    && python3 -m pip install wheel \
    && python3 -m pip install libconf \
    && python3 -m pip install numpy \
    && python3 -m pip install pydot \
    && python3 -m pip install ./accelergy \
    && python3 -m pip install ./accelergy-aladdin-plug-in \
    && cd accelergy-cacti-plug-in && make && cd .. \
    && python3 -m pip install ./accelergy-cacti-plug-in \
    && python3 -m pip install ./accelergy-table-based-plug-ins \
    && python3 -m pip install ./accelergy-neurosim-plug-in \
    && python3 -m pip install ./accelergy-library-plug-in \
    && python3 -m pip install ./accelergy-adc-plug-in \
    && chmod -R 777 $SHARE_DIR/accelergy/estimation_plug_ins


# PyTimeloop

ENV BARVINOK_VER=0.41.6
ENV NTL_VER=11.5.1

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
    && rm -rf /var/lib/apt/lists/*

WORKDIR $BUILD_DIR
RUN wget https://libntl.org/ntl-$NTL_VER.tar.gz \
    && tar -xvzf ntl-$NTL_VER.tar.gz \
    && cd ntl-$NTL_VER/src \
    && ./configure NTL_GMP_LIP=on SHARED=on NATIVE=off \
    && make \
    && make install

WORKDIR $BUILD_DIR
RUN wget https://barvinok.sourceforge.io/barvinok-$BARVINOK_VER.tar.gz \
    && tar -xvzf barvinok-$BARVINOK_VER.tar.gz \
    && cd barvinok-$BARVINOK_VER \
    && ./configure --enable-shared-barvinok \
    && make \
    && make install

WORKDIR $BUILD_DIR

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
               g++ \
               cmake \
               make \
    && cd timeloop/src \
    && ln -s ../pat-public/src/pat . \
    && cd ../../timeloop-python \
    && rm -rf build \
    && apt-get install -y --no-install-recommends \
               libisl-dev \
    && TIMELOOP_INCLUDE_PATH=$BUILD_DIR/timeloop/include \
       TIMELOOP_LIB_PATH=$LIB_DIR \
       python3 -m pip install .


# timeloopfe
WORKDIR $BUILD_DIR
RUN python3 -m pip install setuptools ./timeloopfe

# Set up entrypoint

COPY docker-entrypoint.sh $BIN_DIR
ENTRYPOINT ["bash", "docker-entrypoint.sh"]

WORKDIR /home/workspace
CMD ["bash"]
