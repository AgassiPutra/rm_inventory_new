# Stage 1: Build Flutter Web App
FROM ubuntu:20.04 AS build

# Install dependencies including xz-utils
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Create a user with the appropriate permissions
RUN useradd -m fani

# Switch to non-root user
USER fani

# Set Flutter installation directory and download Flutter SDK
RUN mkdir -p /home/fani/flutter332 \
    && curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.32.8-stable.tar.xz \
    -o /home/fani/flutter332/flutter_linux_3.32.8-stable.tar.xz \
    && tar -xJf /home/fani/flutter332/flutter_linux_3.32.8-stable.tar.xz -C /home/fani/flutter332 \
    && /home/fani/flutter332/flutter/bin/flutter --version

# Add Flutter to PATH
ENV PATH="/home/fani/flutter332/flutter/bin:${PATH}"

# Copy project files with appropriate ownership
COPY --chown=fani:fani . .

# Get dependencies and build
RUN flutter pub get
RUN flutter build web

# Stage 2: Serve Flutter Web with Nginx
FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
