# Axon Production Deployment & Tuning Guide

This document outlines deployment configurations, container orchestration, and kernel tuning best practices for running Axon clusters.

---

## 1. Minimal Cluster Architecture

A standard high-availability Axon deployment consists of:
- **3 or 5 Gateway Nodes**: Stateless HTTP / GraphQL query processors running `axon server`.
- **Replicated Storage / WAL Quorum**: Clustered persistence backing entities and relationship tuples.
- **Prometheus Telemetry Scraper**: Scraping `/metrics` at 5s intervals.

---

## 2. Linux Kernel Optimization

Add the following parameters to `/etc/sysctl.d/99-axon.conf` for high-throughput socket performance:

```ini
# Maximum socket receive / send buffers
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# Increase TCP listen backlog
net.core.somaxconn = 65535

# Enable TCP BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# File descriptor limits
fs.file-max = 2097152
```

---

## 3. Systemd Unit File

Create `/etc/systemd/system/axon.service`:

```ini
[Unit]
Description=Axon Distributed Graph Execution Engine
After=network.target

[Service]
Type=simple
User=axon
Group=axon
WorkingDirectory=/opt/axon
ExecStart=/opt/axon/bin/axon server 9080
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```
