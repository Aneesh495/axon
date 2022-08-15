# Multi-stage Dockerfile for Axon
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    cmake \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN make -C runtime
RUN chmod +x bin/axon

FROM ubuntu:24.04 AS runner

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    python3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/axon
COPY --from=builder /app /opt/axon

EXPOSE 9080 9081 9090

ENTRYPOINT ["/opt/axon/bin/axon"]
CMD ["server", "9080"]
