FROM ubuntu:22.04

# Prevent interactive prompts during apt installation
ENV DEBIAN_FRONTEND=noninteractive

# Install curl and ca-certificates required for downloading pixi
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install pixi
RUN curl -fsSL https://pixi.sh/install.sh | bash
ENV PATH="/root/.pixi/bin:${PATH}"

# Set up the working directory
WORKDIR /workspace

# Copy the pixi project files
COPY pixi.toml pixi.lock* ./

# Install all dependencies specified in pixi.toml
# This creates the .pixi environment
RUN pixi install

# Copy the rest of the project files (scripts, etc.)
COPY . .

# Set the default entrypoint to run commands within the pixi environment
# Using "pixi run" allows executing commands (like bwa, gatk, samtools) 
# seamlessly within the container's environment.
ENTRYPOINT ["pixi", "run"]

# By default, start an interactive bash shell
CMD ["bash"]
