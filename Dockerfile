FROM debian:stable AS build

ARG VERSION="1.35.4"
ARG GHC_VERSION="8.10.7"
ARG CABAL_VERSION="3.6.2.0"

RUN apt-get update && apt-get install -y \
  autoconf \
  automake \
  build-essential \
  curl \
  git \
  jq \
  libffi-dev \
  libgmp-dev \
  liblmdb-dev \
  libncursesw5 \
  libnuma-dev \
  libsodium-dev \
  libssl-dev \
  libsystemd-dev \
  libtinfo-dev \
  libtool \
  pkg-config \
  wget \
  zlib1g-dev

WORKDIR /opt

ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=1
RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
ENV PATH=${PATH}:/root/.local/bin
ENV PATH=${PATH}:/root/.ghcup/bin
RUN ghcup upgrade && \
  ghcup install ghc ${GHC_VERSION} && ghcup set ghc ${GHC_VERSION} && \
  ghcup install cabal ${CABAL_VERSION} && ghcup set cabal ${CABAL_VERSION} && \
  cabal update

RUN git clone https://github.com/input-output-hk/libsodium \
  && cd libsodium \
  && git checkout 66f017f1 \
  && ./autogen.sh \
  && ./configure \
  && make -j16 \
  && make install
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

RUN git clone https://github.com/bitcoin-core/secp256k1 \
  && cd secp256k1 \
  && git checkout ac83be33 \
  && ./autogen.sh \
  && ./configure --enable-module-schnorrsig --enable-experimental \
  && make \
  && make install

RUN git clone https://github.com/input-output-hk/cardano-node.git \
  && cd cardano-node \
  && git fetch --all --recurse-submodules --tags \
  && git tag && git checkout tags/${VERSION} \
  && echo "with-compiler: ghc-${GHC_VERSION}" >> cabal.project.local \
  && echo "package cardano-crypto-praos" >> cabal.project.local \
  && echo "  flags: -external-libsodium-vrf" >> cabal.project.local \
  && cabal update \
  && cabal build -j16 all \
  && mkdir /opt/bin/ \
  && cp -p dist-newstyle/build/x86_64-linux/ghc-${GHC_VERSION}/cardano-node-${VERSION}/x/cardano-node/build/cardano-node/cardano-node /opt/bin/ \
  && cp -p dist-newstyle/build/x86_64-linux/ghc-${GHC_VERSION}/cardano-cli-${VERSION}/x/cardano-cli/build/cardano-cli/cardano-cli /opt/bin/

FROM debian:stable-slim

ARG USERNAME="cardano"
ARG USERID="1000"
ARG GROUPID="1024"

COPY --from=build /usr/local/lib/libsodium.so* /usr/local/lib/
COPY --from=build /usr/local/lib/libsecp256k1.so* /usr/local/lib/
COPY --from=build /opt/bin/cardano-cli /usr/local/bin/
COPY --from=build /opt/bin/cardano-node /usr/local/bin/

ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

RUN apt-get update && apt-get install -y --no-install-recommends \
  netbase \
  libc-dev \
  jq \
  && rm -rf /var/lib/apt/lists/*

RUN groupadd -g ${GROUPID} -r ${USERNAME} \
  && useradd --no-log-init -r --gid ${GROUPID} -u ${USERID} ${USERNAME} \
  && mkdir /home/${USERNAME} \
  && chown -R ${USERID}:${GROUPID} /home/${USERNAME} \
  && echo ${USERNAME}:${USERNAME} | chpasswd

USER ${USERNAME}

ENTRYPOINT ["cardano-node"]
