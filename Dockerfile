FROM ghcr.io/prefix-dev/pixi:latest

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /workspace

# Copy lockfiles first — layer cache reused until pixi.toml/pixi.lock change
COPY pixi.toml pixi.lock* ./

# --frozen: use exact lockfile versions, never re-resolve
RUN pixi install --frozen

COPY . .

ENTRYPOINT ["pixi", "run"]
CMD ["bash"]
