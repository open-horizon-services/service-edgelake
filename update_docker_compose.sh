#!/bin/bash

set -e

# Define paths
COMPOSE_FILE="docker-makefiles/docker-compose-temp-base.yaml"
OUTPUT_FILE="docker-makefiles/docker-compose-template.yaml"
cp ${DOCKER_COMPOSE_TEMPLATE} ${COMPOSE_FILE}

# Add broker port mapping if set and not on Linux
if [[ -n "$ANYLOG_BROKER_PORT" && "$ANYLOG_BROKER_PORT" != "''" && "$ANYLOG_BROKER_PORT" != '""' && "$OS" != "linux" ]]; then
  awk -v port="\${ANYLOG_BROKER_PORT}:\${ANYLOG_BROKER_PORT}" '
    /    ports:/ {print; print "      - " port; next}1' "$COMPOSE_FILE" > temp.yaml && mv temp.yaml "$COMPOSE_FILE"
fi

# Add Nebula settings if enabled
if [[ "$ENABLE_NEBULA" == "true" ]]; then
  [[ "$OS" != "linux" ]] && awk -v port="4242:4242" '
    /    ports:/ {print; print "      - " port; next}1' "$COMPOSE_FILE" > temp.yaml && mv temp.yaml "$COMPOSE_FILE"

  awk -v volume="nebula-overlay:/app/nebula" '
    /    volumes:/ && !found++ {print; print "      - " volume; next}
    {print}
    END {print "  nebula-overlay:"}' "$COMPOSE_FILE" > temp.yaml && mv temp.yaml "$COMPOSE_FILE"

  awk '
    /services:/,/^volumes:/ {
      print
      if (/    stdin_open:/) {
        print "    cap_add:\n      - NET_ADMIN"
        print "    devices:\n      - \"/dev/net/tun:/dev/net/tun\""
      }
      next
    }1' "$COMPOSE_FILE" > temp.yaml && mv temp.yaml "$COMPOSE_FILE"
fi

# Add Remote CLI if enabled
if [[ "$REMOTE_CLI" == "true" ]]; then
  for vol in \
    "remote-cli:/app/Remote-CLI/djangoProject/static/json" \
    "remote-cli-current:/app/Remote-CLI/djangoProject/static/blobs/current/"
  do
    awk -v volume="$vol" '
      /    volumes:/ && !found++ {print; print "      - " volume; next}
      {print}
      END {split(volume, v, ":"); print "  " v[1] ":"}' "$COMPOSE_FILE" > temp.yaml && mv temp.yaml "$COMPOSE_FILE"
  done

  awk '/services:/ {
    print
    print "  remote-cli:"
    print "    image: anylogco/remote-cli:latest"
    print "    container_name: remote-cli"
    print "    restart: always"
    print "    stdin_open: true"
    print "    tty: true"
    print "    ports:"
    print "      - 31800:31800"
    print "    environment:"
    print "      - CONN_IP=0.0.0.0"
    print "      - CLI_PORT=31800"
    print "    volumes:"
    print "      - remote-cli:/app/Remote-CLI/djangoProject/static/json"
    print "      - remote-cli-current:/app/Remote-CLI/djangoProject/static/blobs/current/"
    next
  }1' "$COMPOSE_FILE" > temp.yaml && mv temp.yaml "$COMPOSE_FILE"
fi

# Finalize
cp "$COMPOSE_FILE" "$OUTPUT_FILE"
rm -f "$COMPOSE_FILE"

echo "✅ Modified docker-compose file saved as $OUTPUT_FILE"
