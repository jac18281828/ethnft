FROM debian:stable-slim as builder

RUN export DEBIAN_FRONTEND=noninteractive && \
  apt update && \
  apt install -y -q --no-install-recommends \
  git curl gnupg2 build-essential openssl libssl-dev pkg-config \
  ca-certificates apt-transport-https && \
  apt clean && \
  rm -rf /var/lib/apt/lists/*

RUN useradd --create-home -s /bin/bash jac
RUN usermod -a -G sudo jac
RUN echo '%jac ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

## Go Lang
ARG GO_VERSION=1.18.5
ARG PROCESSOR_ARCH=amd64
ADD https://go.dev/dl/go${GO_VERSION}.linux-${PROCESSOR_ARCH}.tar.gz /go-ethereum/go${GO_VERSION}.linux-${PROCESSOR_ARCH}.tar.gz
RUN tar -C /usr/local -xzf /go-ethereum/go${GO_VERSION}.linux-${PROCESSOR_ARCH}.tar.gz
ENV PATH=$PATH:/usr/local/go/bin
RUN go version

## Go Ethereum
WORKDIR /go-ethereum
ARG ETH_VERSION=1.10.21
ADD https://github.com/ethereum/go-ethereum/archive/refs/tags/v${ETH_VERSION}.tar.gz /go-ethereum/${ETH_VERSION}.tar.gz
RUN tar -zxf ${ETH_VERSION}.tar.gz  -C /go-ethereum
WORKDIR /go-ethereum/go-ethereum-${ETH_VERSION}
RUN go mod download 
RUN go run build/ci.go install

## Rust
ADD https://sh.rustup.rs /rustup/rustup-init.sh
RUN chmod 755 /rustup/rustup-init.sh 

WORKDIR /rustup
ENV USER=jac
USER jac
RUN /rustup/rustup-init.sh -y --default-toolchain stable --profile minimal

## Foundry
WORKDIR /foundry

# latest https://github.com/foundry-rs/foundry
RUN ~jac/.cargo/bin/cargo install --git https://github.com/foundry-rs/foundry --locked foundry-cli

FROM debian:stable-slim

RUN export DEBIAN_FRONTEND=noninteractive && \
  apt update && \
  apt install -y -q --no-install-recommends \
  git gnupg2 curl build-essential \
  sudo ripgrep npm \
  ca-certificates apt-transport-https && \
  apt clean && \
  rm -rf /var/lib/apt/lists/*


# RUN npm install npm -g
RUN npm install yarn -g

RUN useradd --create-home -s /bin/bash jac
RUN usermod -a -G sudo jac
RUN echo '%jac ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# GO LANG
COPY --from=builder /usr/local/go /usr/local/go

## GO Ethereum Binaries
ARG ETH_VERSION=1.10.21
COPY --from=builder /go-ethereum/go-ethereum-${ETH_VERSION}/build/bin /usr/local/bin
COPY --chown=jac:jac --from=builder /home/jac/.cargo /home/jac/.cargo

ARG PROJECT=focusnft
WORKDIR /workspaces/${PROJECT}
RUN chown -R jac.jac .
COPY --chown=jac:jac . .
ENV USER=jac
USER jac
ENV PATH=${PATH}:~/.cargo/bin
RUN yarn install
RUN yarn lint
RUN ~jac/.cargo/bin/forge test -vvv


