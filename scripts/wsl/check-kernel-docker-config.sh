#!/usr/bin/env bash
# Grep-based checker for Docker-related CONFIG_* in a kernel .config file.
# Usage: ./check-kernel-docker-config.sh /path/to/.config
# Exit 0 if all required symbols appear enabled (=y or =m); non-zero otherwise.
#
# Full validation: use upstream check-config.sh from opencontainers/runc.

set -euo pipefail

CONFIG_FILE="${1:-}"

if [[ -z "${CONFIG_FILE}" || ! -f "${CONFIG_FILE}" ]]; then
  echo "Usage: $0 /path/to/.config" >&2
  exit 2
fi

# Symbols that must be =y for typical Docker/runc (plan + check-config.sh core)
REQUIRED_Y=(
  CONFIG_NAMESPACES
  CONFIG_NET_NS
  CONFIG_PID_NS
  CONFIG_IPC_NS
  CONFIG_UTS_NS
  CONFIG_CGROUPS
  CONFIG_CGROUP_CPUACCT
  CONFIG_CGROUP_DEVICE
  CONFIG_CGROUP_FREEZER
  CONFIG_CGROUP_SCHED
  CONFIG_CPUSETS
  CONFIG_MEMCG
  CONFIG_KEYS
  CONFIG_POSIX_MQUEUE
  CONFIG_VETH
  CONFIG_BRIDGE
  CONFIG_BRIDGE_NETFILTER
  CONFIG_NF_NAT
  CONFIG_IP_NF_FILTER
  CONFIG_IP_NF_NAT
  CONFIG_IP_NF_TARGET_MASQUERADE
  CONFIG_NETFILTER_XT_MATCH_ADDRTYPE
  CONFIG_NETFILTER_XT_MATCH_CONNTRACK
  CONFIG_OVERLAY_FS
  CONFIG_IKCONFIG
  CONFIG_IKCONFIG_PROC
)

# Often =y; =m may fail runtime checks — report separately
RECOMMENDED_Y=(
  CONFIG_CGROUP_BPF
  CONFIG_NF_NAT_NEEDED
  CONFIG_IP_NF_MANGLE
  CONFIG_IP_NF_RAW
  CONFIG_IP6_NF_FILTER
  CONFIG_IP6_NF_MANGLE
  CONFIG_IP6_NF_RAW
  CONFIG_IP6_NF_NAT
  CONFIG_IP6_NF_TARGET_MASQUERADE
  CONFIG_NETFILTER_XT_MATCH_IPVS
  CONFIG_NETFILTER_XT_MARK
  CONFIG_IP_VS
  CONFIG_USER_NS
)

fail=0

check_y() {
  local sym="$1"
  if grep -qE "^${sym}=y" "${CONFIG_FILE}"; then
    echo "OK   ${sym}=y"
  elif grep -qE "^${sym}=m" "${CONFIG_FILE}"; then
    echo "WARN ${sym}=m (prefer =y for Docker)"
    fail=1
  elif grep -qE "^${sym}=n" "${CONFIG_FILE}"; then
    echo "FAIL ${sym}=n"
    fail=1
  else
    echo "FAIL ${sym} missing"
    fail=1
  fi
}

echo "Checking: ${CONFIG_FILE}"
echo "--- required (=y) ---"
for sym in "${REQUIRED_Y[@]}"; do
  check_y "${sym}"
done

echo "--- recommended (=y) ---"
for sym in "${RECOMMENDED_Y[@]}"; do
  check_y "${sym}" || true
done

# NetHunter injection (Phase 5 — not Docker, but same checklist doc)
if grep -qE "^CONFIG_FEATURE_FRAME_INJECTION_SUPPORT=y" "${CONFIG_FILE}"; then
  echo "OK   CONFIG_FEATURE_FRAME_INJECTION_SUPPORT=y (injection)"
elif grep -qE "^CONFIG_FEATURE_FRAME_INJECTION_SUPPORT=" "${CONFIG_FILE}"; then
  echo "INFO CONFIG_FEATURE_FRAME_INJECTION_SUPPORT present but not =y"
else
  echo "INFO CONFIG_FEATURE_FRAME_INJECTION_SUPPORT missing (enable after qcacld patch step)"
fi

echo "---"
if [[ "${fail}" -ne 0 ]]; then
  echo "Some required options missing or not built-in (=y). Fix defconfig and rebuild."
  echo "Also run: curl -fsSL https://raw.githubusercontent.com/opencontainers/runc/main/script/check-config.sh | bash -s -- --kernel-config ${CONFIG_FILE}"
  exit 1
fi

echo "All required Docker CONFIG_* symbols look enabled."
exit 0
