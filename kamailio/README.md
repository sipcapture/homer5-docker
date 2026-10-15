# sipcapture/homer-kamailio

Homer 5 Kamailio HEP capture agent (UDP port 9060 by default).

```bash
docker build -t sipcapture/homer-kamailio .
```

Publish `9060/udp` and point HEP senders at the Docker host address.
