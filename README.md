# cardano-node
Minimal Dockerfile for cardano-node

## Build

```
docker build . -t theodus/cardano-node:latest
```

## Deploy

The following example assumes all configuration files are placed in
`/var/lib/cardano` on the host with appropriate permissions for the cardano user
(UID 1000, GID 1024).

```
docker run --rm --name cardano-node \
  -v /var/lib/cardano:/home/cardano/ \
  -p 3000:3000 \
  -p 12798:12798 \
  theodus/cardano-node run \
    --host-addr 0.0.0.0 \
    --port 3000 \
    --database-path /home/cardano/cardano-node/db/ \
    --socket-path /home/cardano/cardano-node/db/node.socket \
    --config /home/cardano/cardano-node/mainnet-config.json \
    --topology /home/cardano/cardano-node/mainnet-topology.json
```
