
FROM teego/steem-base:0.3-Ubuntu-xenial

MAINTAINER Aleksandr Zykov <tiger@mano.email>

ENV DEBIAN_FRONTEND="noninteractive"

ENV DEBIAN_FRONTEND noninteractive

RUN figlet "MinGW" &&\
    ( \
        apt-get install -qy --no-install-recommends \
            build-essential \
            mingw-w64 \
            g++-mingw-w64 \
            git \
            psmisc \
            make \
            nsis \
            autoconf \
            libtool \
            automake \
            pkg-config \
            bsdmainutils \
            python-dev \
            faketime \
    ) &&\
    apt-get clean -qy

RUN x86_64-w64-mingw32-g++ --version

ENV BUILDBASE /r

ENV BUILDROOT $BUILDBASE/build
ENV MINGWROOT $BUILDBASE/mingw

RUN mkdir -p $BUILDROOT $MINGWROOT/lib

RUN figlet "JWasm" &&\
    ( \
        cd $BUILDROOT; \
        ( \
            git clone https://github.com/JWasm/JWasm.git jwasm &&\
            ( \
                cd jwasm; \
                ( \
                    make -f GccUnix.mak &&\
                    cp GccUnixR/jwasm /usr/bin/ \
                ) \
            ) \
        ) \
    )

ENV OPENSSL_VERSION 1.0.2h

RUN figlet "OpenSSL" &&\
    ( \
        cd $BUILDROOT; \
        wget -O openssl-$OPENSSL_VERSION.tar.gz \
            https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz &&\
        tar xfz openssl-$OPENSSL_VERSION.tar.gz &&\
        ( \
            cd openssl-$OPENSSL_VERSION; \
            ( \
                ( \
                    env CROSS_COMPILE="x86_64-w64-mingw32-" ./Configure mingw64 no-asm --openssldir="$MINGWROOT" \
                ) &&\
                make depend &&\
                make &&\
                make install \
            ) \
        ) \
    )

ENV BOOST_VERSION 1.60.0

RUN figlet "Boost" &&\
    mkdir -p $BUILDROOT/boost-build &&\
    ( \
        cd $BUILDROOT; \
        wget -O boost_`echo $BOOST_VERSION | sed 's/\./_/g'`.tar.gz \
            http://sourceforge.net/projects/boost/files/boost/$BOOST_VERSION/boost_`echo $BOOST_VERSION | sed 's/\./_/g'`.tar.gz/download &&\
        tar xfz boost_`echo $BOOST_VERSION | sed 's/\./_/g'`.tar.gz &&\
        ( \
            cd boost_`echo $BOOST_VERSION | sed 's/\./_/g'`; \
            ( \
                ( \
                    echo "using gcc : mingw : x86_64-w64-mingw32-g++ ;" > user-config.jam \
                ) &&\
                ( \
                    ./bootstrap.sh \
                        --without-icu \
                        --prefix=$MINGWROOT \
                ) &&\
                ( \
                    ./b2 --user-config=user-config.jam \
                        --layout=tagged \
                        toolset=gcc-mingw \
                        target-os=windows \
                        variant=release \
                        link=static \
                        threading=multi \
                        threadapi=win32 \
                        abi=ms \
                        architecture=x86 \
                        binary-format=pe \
                        address-model=64 \
                        -sNO_BZIP2=1 \
                        --build-dir=$BUILDROOT/boost-build \
                        --without-mpi \
                        --without-python \
                        install ||\
                    /bin/true\
                ) \
            ) \
        ) \
    )

ENV STEEM_VERSION 0.12.3a

RUN figlet "Steem" &&\
    mkdir -p $BUILDBASE/dist/steem-v$STEEM_VERSION-mingw64 &&\
    ( \
        cd $BUILDROOT; \
        ( \
            git clone https://github.com/steemit/steem.git steem-src &&\
            cd steem-src ;\
            ( \
                git checkout v$STEEM_VERSION &&\
                git submodule update --init --recursive \
            ) \
        ) \
    ) &&\
    ( \
        cd $BUILDROOT; \
        ( \
            mkdir -p steem-mingw &&\
            ( \
                cd steem-mingw ;\
                ( \
                    cmake \
                        -DLOW_MEMORY_NODE=ON \
                        -DENABLE_CONTENT_PATCHING=OFF \
                        -DFULL_STATIC_BUILD=ON \
                        -DCMAKE_SYSTEM_NAME=Windows \
                        -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
                        -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
                        -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres \
                        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
                        -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
                        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
                        -DCMAKE_BUILD_TYPE=RELEASE \
                        -DCMAKE_FIND_ROOT_PATH=$MINGWROOT $BUILDROOT/steem-src \
                        -DOPENSSL_ROOT_DIR=$MINGWROOT \
                        -DBoost_USE_STATIC_LIBS=ON \
                        -DBoost_THREADAPI=win32 \
                        -DCMAKE_INSTALL_PREFIX=$BUILDBASE/dist/steem-v$STEEM_VERSION-mingw64 &&\
                    make &&\
                    make install \
                ) \
            ) \
        ) \
    )

RUN figlet "Package" &&\
    ( \
        cd $BUILDBASE/dist; \
        (\
            zip -r $BUILDBASE/steem-v$STEEM_VERSION-mingw64.zip \
              steem-v$STEEM_VERSION-mingw64 \
        ) \
    )

RUN ( \
        cd $BUILDBASE; \
        (\
            sha256sum steem-v$STEEM_VERSION-mingw64.zip \
        ) \
    )

RUN figlet "Ready!"
