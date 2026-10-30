# Docker on Android — kernel `CONFIG_*` checklist

Options required for **real Docker/runc** on a custom NetHunter kernel (SM8350 / porsche). Sourced from the project plan and [opencontainers/runc `check-config.sh`](https://github.com/opencontainers/runc/blob/main/script/check-config.sh) **mandatory** / commonly flagged items for container networking and storage.

Enable as **`=y`** unless your tree only supports module (`=m`) for a specific symbol — run the full checker to confirm.

## Process isolation

- `CONFIG_NAMESPACES`
- `CONFIG_NET_NS`
- `CONFIG_PID_NS`
- `CONFIG_IPC_NS`
- `CONFIG_UTS_NS`
- `CONFIG_USER_NS` (often needed for rootless; verify with `check-config.sh`)
- `CONFIG_CGROUPS`
- `CONFIG_CGROUP_CPUACCT`
- `CONFIG_CGROUP_DEVICE`
- `CONFIG_CGROUP_FREEZER`
- `CONFIG_CGROUP_SCHED`
- `CONFIG_CGROUP_BPF`
- `CONFIG_CPUSETS`
- `CONFIG_MEMCG`
- `CONFIG_KEYS`
- `CONFIG_POSIX_MQUEUE`

## Networking (bridges, NAT, filters)

- `CONFIG_VETH`
- `CONFIG_BRIDGE`
- `CONFIG_BRIDGE_NETFILTER`
- `CONFIG_NF_NAT`
- `CONFIG_NF_NAT_NEEDED`
- `CONFIG_IP_NF_FILTER`
- `CONFIG_IP_NF_MANGLE`
- `CONFIG_IP_NF_RAW`
- `CONFIG_IP_NF_NAT`
- `CONFIG_IP_NF_TARGET_MASQUERADE`
- `CONFIG_IP6_NF_FILTER`
- `CONFIG_IP6_NF_MANGLE`
- `CONFIG_IP6_NF_RAW`
- `CONFIG_IP6_NF_NAT`
- `CONFIG_IP6_NF_TARGET_MASQUERADE`
- `CONFIG_NETFILTER_XT_MATCH_ADDRTYPE`
- `CONFIG_NETFILTER_XT_MATCH_CONNTRACK`
- `CONFIG_NETFILTER_XT_MATCH_IPVS`
- `CONFIG_NETFILTER_XT_MARK`
- `CONFIG_IP_VS` (when using `-m ipvs` / certain networking modes)

## Storage

- `CONFIG_OVERLAY_FS`

## Verification / debug

- `CONFIG_IKCONFIG` — embed config in kernel image
- `CONFIG_IKCONFIG_PROC` — expose **`/proc/config.gz`** on device

## Wi-Fi injection (NetHunter — not Docker, same build phase)

- `CONFIG_FEATURE_FRAME_INJECTION_SUPPORT` — qcacld-3.0 frame injection (WCN6856)

## How to verify

1. **WSL2**, after `make` / builder **`2`**:

   ```bash
   ./scripts/wsl/check-kernel-docker-config.sh /path/to/kernel/.config
   curl -fsSL -o /tmp/check-config.sh \
     https://raw.githubusercontent.com/opencontainers/runc/main/script/check-config.sh
   bash /tmp/check-config.sh --kernel-config /path/to/kernel/.config
   ```

2. **On device**, after flashing:

   ```bash
   adb shell su -c 'cat /proc/config.gz' > device-config.gz
   zcat device-config.gz > device.config
   bash /tmp/check-config.sh --kernel-config device.config
   ```

3. Optional runtime helper from NetHunter kernels: **`nh-docker`** ([Kali MR !448](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernels/-/merge_requests/448)).

See [phases/05-build-kernel-detailed.md](phases/05-build-kernel-detailed.md) for the full Phase 5 workflow.
