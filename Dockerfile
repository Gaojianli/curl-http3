FROM alpine:edge AS builder

LABEL maintainer="Yury Muski <muski.yury@gmail.com>"

WORKDIR /opt

RUN apk add --no-cache build-base git autoconf git libpsl-dev libtool cmake go curl nghttp2-dev zlib-dev automake rustup && rustup-init -y -q

RUN git clone --recursive https://github.com/cloudflare/quiche

# build quiche
RUN cd quiche && git checkout $(curl -s https://api.github.com/repos/cloudflare/quiche/releases/latest|jq .tag_name|tr -d \" \ ) && \
    PATH="$HOME/.cargo/bin:$PATH" cargo build --package quiche --release --features ffi,pkg-config-meta,qlog && \
    mkdir quiche/deps/boringssl/src/lib && \
    ln -vnf $(find target/release -name libcrypto.a -o -name libssl.a) quiche/deps/boringssl/src/lib/

# add curl
RUN git clone https://github.com/curl/curl && cd curl && \
    git checkout $(curl -s https://api.github.com/repos/curl/curl/releases/latest|jq .tag_name|tr -d \" \  ) && \
    autoreconf -fi && \
    ./configure LDFLAGS="-Wl,-rpath,/opt/quiche/target/release" --with-openssl=/opt/quiche/quiche/deps/boringssl/src --with-quiche=/opt/quiche/target/release --with-nghttp2 --with-zlib && \
    make -j $(nproc) && \
    make DESTDIR="/curl/" install

FROM alpine:edge
RUN apk add --no-cache nghttp2 zlib libpsl bash perl
COPY --from=builder /curl/usr/local/ /usr/local/

WORKDIR /opt
# add httpstat script
RUN curl -s https://raw.githubusercontent.com/b4b4r07/httpstat/master/httpstat.sh >httpstat.sh && chmod +x httpstat.sh

CMD ["curl"]
