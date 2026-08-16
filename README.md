# seiscomp-scmaster

![CI](https://github.com/platformfuzz/seiscomp-scmaster/actions/workflows/ci.yml/badge.svg)
![Build and Release](https://github.com/platformfuzz/seiscomp-scmaster/actions/workflows/build-and-release.yml/badge.svg)

Unofficial SeisComP scmaster image built with public gsm. Not gempa-supported.

Loads LEARN GEOFON inventory into MariaDB, then listens on TCP 18180.

**Package:** [ghcr.io/platformfuzz/seiscomp-scmaster](https://github.com/platformfuzz/seiscomp-scmaster/pkgs/container/seiscomp-scmaster)

## Run

```bash
docker pull ghcr.io/platformfuzz/seiscomp-scmaster:latest
docker run --rm ghcr.io/platformfuzz/seiscomp-scmaster:latest
```

Needs a reachable MariaDB (`DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`).

## Build

```bash
docker build -t seiscomp-scmaster:test .
```

`SCMASTER` messaging bind is `0.0.0.0:18180`.
