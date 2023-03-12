# Introduction - mDNS repeat in Mikrotik RouterOS
It is a well-known best practice to isolate IoT devices in a dedicated -more restrictive- network due to potential always zero-day security vulnerabilities when they reach their End Of Life and no more firmware updates are received. However, many interaction with these devices relies on mDNS based discovery, that uses a multicast domain, tied to the network the device is in. Although most of the times the interaction with the device works well from other network as long as it is properly routed, the lack of mDNS announcements may render their software unusable.

RouterOS lack this kind of functionality, but it can be implemented thanks to the containers support in v7.

This container is to allow Mikrotik devices to repeat mDNS traffic between two different networks. This way you can get the mDNS from a -for example- IoT network and repeat into another one.

## This is a fork based on...
* [geekman/mdns-repeater](https://github.com/geekman/mdns-repeater)
* [monstrenyatko/docker-mdns-repeater](https://github.com/monstrenyatko/docker-mdns-repeater)
* [TheMickeyMike/docker-mdns-repeater-mikrotik](https://github.com/TheMickeyMike/docker-mdns-repeater-mikrotik)
* [mag1024/mikrotik-docker-mdns-repeater](https://github.com/mag1024/mikrotik-docker-mdns-repeater)

## How it works
As of Oct 2022, the Mikrotik container implementation is limited to exactly one
network interface. There is no option for an equivalent of 'host' mode
networking, and the interface must be of type veth, so we have to get creative
to get a functional repeater. The key is to attach the venth to a trunk bridge
that contains multiple vlans corresponding to the networks we want to repeat
across, and then create interfaces for each of the vlans inside the container,
using the veth as the parent. The set of vlans/interfaces to use is specified
via the `REPEATER_INTERFACES` env variable, and the container runs a dhcp client
to obtain an IP for each of them.

## Build & pack container
A Makefile is provided to ease the build process, but it you have to do manually:
```
docker buildx build --no-cache --platform linux/arm/v6 -t mdns .
docker save mdns -o mdns.tar
8.8M mdns.tar # size after pack
```

## Setup
Begin by following the [Mikrotik container
documentation](https://help.mikrotik.com/docs/display/ROS/Container) to create
the veth interface.  Instead of creating a separate docker bridge, assign the
new interface as a 'tagged' port to the bridge containing the interfaces you
wish to repeat across.  These interfaces can be vlan interfaces, or physical
interfaces with pvid set -- depending on whether you use vlans for the rest of
your network setup. Refer to the [Mikrotik bridge
documentation](https://help.mikrotik.com/docs/display/ROS/Bridge+VLAN+Table) for
more details.

The following example uses _veth-trunk_ veth interface and _br-trunk_ bridge,
configured with vlans 10, 11, 12.

Note: The address here does not matter, but it must have one to make the
interface 'active'.
```
/interface/veth/print
Flags: X - disabled; R - running
 0  R name="veth-trunk" address=10.200.200.200/24 gateway=10.200.200.1
```

Note: Again, pvid of the _veth_ itself does not matter.
```
/interface/bridge/port/print
Flags: I - INACTIVE; H - HW-OFFLOAD
Columns: INTERFACE, BRIDGE, HW, PVID, PRIORITY, PATH-COST, INTERNAL-PATH-COST, HORIZON
#    INTERFACE     BRIDGE    HW   PVID  PRIORITY  PATH-COST  INTERNAL-PATH-COST  HORIZON
0  H ether2        br-trunk  yes    10  0x80             10                  10  none
1  H ether3        br-trunk  yes    13  0x80             10                  10  none
...
8    veth-trunk    br-trunk        111  0x80             10                  10  none
```

Note: The name of the interface inside the container is always _eth0_.
```
/container/envs/print
 0 name="repeater_envs" key="REPEATER_INTERFACES" value="eth0.10 eth0.11 eth0.12"
```

Note: you may have to set the registry first via `/container/config/set registry-url=https://registry-1.docker.io`.
Note: `start-on-boot` is only available on Mikrotik 7.6+
```
/container/print
 0 ... tag="mag1024/mikrotik-docker-mdns-repeater:latest" os="linux"
   arch="arm64" interface=veth-trunk envlist="repeater_envs" mounts="" dns="" hostname="mdns-repeater" logging=yes
   start-on-boot=yes status=running
```

## Logs from running container
```
log print where topics~"container"
 jun/29 22:01:28 container,info,debug create interface eth0.20
 jun/29 22:01:28 container,info,debug bring up eth0.20 interface
 jun/29 22:01:28 container,info,debug /app/run.sh: line 25: kill: (19) - No such process
 jun/29 22:01:28 container,info,debug starting dhcp client on eth0.20
 jun/29 22:01:28 container,info,debug udhcpc: started, v1.35.0
 jun/29 22:01:29 container,info,debug udhcpc: broadcasting discover
 jun/29 22:01:29 container,info,debug udhcpc: broadcasting select for 10.0.20.27, server 10.0.20.1
 jun/29 22:01:29 container,info,debug udhcpc: lease of 10.0.20.27 obtained from 10.0.20.1, lease time 86400
 jun/29 22:01:29 container,info,debug create interface eth0.100
 jun/29 22:01:29 container,info,debug bring up eth0.100 interface
 jun/29 22:01:29 container,info,debug /app/run.sh: line 25: kill: (34) - No such process
 jun/29 22:01:29 container,info,debug starting dhcp client on eth0.100
 jun/29 22:01:29 container,info,debug udhcpc: started, v1.35.0
 jun/29 22:01:29 container,info,debug udhcpc: broadcasting discover
 jun/29 22:01:30 container,info,debug udhcpc: broadcasting select for 10.0.100.244, server 10.0.100.1
 jun/29 22:01:30 container,info,debug udhcpc: lease of 10.0.100.244 obtained from 10.0.100.1, lease time 86400
 jun/29 22:01:30 container,info,debug + exec /bin/mdns-repeater -f eth0.20 eth0.100
 jun/29 22:01:30 container,info,debug mdns-repeater: dev eth0.20 addr 10.0.20.27 mask 255.255.255.0 net 10.0.20.0
 jun/29 22:01:30 container,info,debug mdns-repeater: dev eth0.100 addr 10.0.100.244 mask 255.255.255.0 net 10.0.100.0
 jul/01 21:49:34 container,info,debug bring up eth0.20 interface
 jul/01 21:49:34 container,info,debug /app/run.sh: line 25: kill: (22) - No such process
 jul/01 21:49:34 container,info,debug starting dhcp client on eth0.20
 jul/01 21:49:34 container,info,debug udhcpc: started, v1.35.0
 jul/01 21:49:34 container,info,debug udhcpc: broadcasting discover
 jul/01 21:49:34 container,info,debug udhcpc: broadcasting select for 10.0.20.27, server 10.0.20.1
 jul/01 21:49:34 container,info,debug udhcpc: lease of 10.0.20.27 obtained from 10.0.20.1, lease time 86400
 jul/01 21:49:34 container,info,debug bring up eth0.100 interface
 jul/01 21:49:34 container,info,debug /app/run.sh: line 25: kill: (40) - No such process
 jul/01 21:49:34 container,info,debug starting dhcp client on eth0.100
 jul/01 21:49:34 container,info,debug udhcpc: started, v1.35.0
 jul/01 21:49:34 container,info,debug udhcpc: broadcasting discover
 jul/01 21:49:35 container,info,debug udhcpc: broadcasting select for 10.0.100.244, server 10.0.100.1
 jul/01 21:49:35 container,info,debug udhcpc: lease of 10.0.100.244 obtained from 10.0.100.1, lease time 86400
 jul/01 21:49:35 container,info,debug + exec /bin/mdns-repeater -f eth0.20 eth0.100
 jul/01 21:49:35 container,info,debug mdns-repeater: dev eth0.20 addr 10.0.20.27 mask 255.255.255.0 net 10.0.20.0
 jul/01 21:49:35 container,info,debug mdns-repeater: dev eth0.100 addr 10.0.100.244 mask 255.255.255.0 net 10.0.100.0
```
