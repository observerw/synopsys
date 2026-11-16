# SCL license server

## Run

```sh
docker run -d --name license --restart=always \
  --network eda --network-alias lic1 \
  --cap-add=NET_ADMIN \
  --mac-address 52:54:00:ad:a0:86 \
  -p 2700:2700 -p 2701:2701 \
  local.io/synopsys/scl:2025.03
```

`sudo nerdctl run` works identically; drop `--network`/`--network-alias` only
when the clients do not need to resolve `lic1` (see the notes below).

## Check

```sh
docker exec license lmutil lmstat -c 2700@127.0.0.1
```

## Notes

- Both Docker and containerd work. `snpslmd` treats `/.dockerenv`,
  `/.dockerinit` and `docker`/`lxc` in `/proc/*/cgroup` as a non-privileged
  container and exits; `entrypoint.sh` removes the two markers. With
  `--cgroupns=host` the cgroup path still contains `docker` and it refuses.
- `NET_ADMIN` lets `entrypoint.sh` set `eth0` to the MAC the license is bound to.
- The license's `SERVER` line names `lic1`, so give the container that alias
  (or the `lic1` Service in Kubernetes). Clients use
  `SNPSLMD_LICENSE_FILE=2700@lic1` (`2700@license` in Kubernetes).
