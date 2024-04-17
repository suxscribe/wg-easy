# As a workaround we have to build on nodejs 18
# nodejs 20 hangs on build with armv6/armv7
FROM docker.io/library/node:18-alpine AS build_node_modules

# Copy Web UI
COPY src/ /app/
COPY webui/ /webui/
WORKDIR /app
RUN npm ci --omit=dev &&\
    # Enable this to run `npm run serve`
    npm i -g nodemon &&\
    # Delete unnecessary files 
    npm cache clean --force && rm -rf ~/.npm &&\
    mv node_modules /node_modules
WORKDIR /webui
RUN npm ci &&\
    npm run build

# Copy build result to a new image.
# This saves a lot of disk space.
FROM docker.io/library/node:20-alpine

# Copy the server files and the built static files
COPY --from=build_node_modules /app /app
COPY --from=build_node_modules /webui/dist/ /app/www

# Move node_modules one directory up, so during development
# we don't have to mount it in a volume.
# This results in much faster reloading!
#
# Also, some node_modules might be native, and
# the architecture & OS of your development machine might differ
# than what runs inside of docker.
COPY --from=build_node_modules /node_modules /node_modules

# Install Linux packages
RUN apk add --no-cache \
    dpkg \
    dumb-init \
    iptables \
    iptables-legacy \
    wireguard-tools

# Use iptables-legacy
RUN update-alternatives --install /sbin/iptables iptables /sbin/iptables-legacy 10 --slave /sbin/iptables-restore iptables-restore /sbin/iptables-legacy-restore --slave /sbin/iptables-save iptables-save /sbin/iptables-legacy-save

# Expose Ports (If needed on buildtime)
#EXPOSE 51820/udp
#EXPOSE 51821/tcp

# Set Environment
ENV DEBUG=Server,WireGuard

# Run Web UI
WORKDIR /app
CMD ["/usr/bin/dumb-init", "node", "server.js"]
