FROM alpine AS builder
ARG MDNS_REPEATER_VERSION=local

ADD mdns-repeater.c mdns-repeater.c
RUN set -ex \
    && apk add build-base \
    && gcc -o /bin/mdns-repeater mdns-repeater.c -DMDNS_REPEATER_VERSION=\"${MDNS_REPEATER_VERSION}\" \
    && chmod +x /bin/mdns-repeater

FROM alpine

LABEL REPEATER_INTERFACES="Interfaces to repeat mDNS. For example: eth0 eth0.11"

RUN apk add vlan libcap bash

COPY --from=builder /bin/mdns-repeater /bin/mdns-repeater
COPY entrypoint.bash /

RUN setcap cap_net_raw=+ep /bin/mdns-repeater

ENTRYPOINT ["/entrypoint.bash"]
