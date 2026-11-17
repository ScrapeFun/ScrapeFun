#!/usr/bin/env bash

# Configure a Debian Docker host for ScrapeFun's NVIDIA + NCNN (Vulkan) path.
# Run this script as a normal user with permission to run Docker. It invokes
# sudo only for host-level changes, so the subsequent deployment stays owned
# by the invoking user.

set -euo pipefail

readonly NVIDIA_KEYRING='/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg'
readonly NVIDIA_SOURCE_LIST='/etc/apt/sources.list.d/nvidia-container-toolkit.list'
readonly NVIDIA_GPG_KEY_URL='https://nvidia.github.io/libnvidia-container/gpgkey'
readonly NVIDIA_SOURCE_LIST_URL='https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list'
readonly CUDA_TEST_IMAGE_DEFAULT='nvidia/cuda:12.6.3-base-debian12'
readonly SCRAPEFUN_IMAGE_DEFAULT='haoweil/scrapefun:latest'

CUDA_TEST_IMAGE="${CUDA_TEST_IMAGE:-${CUDA_TEST_IMAGE_DEFAULT}}"
SCRAPEFUN_IMAGE="${SCRAPEFUN_IMAGE:-${SCRAPEFUN_IMAGE_DEFAULT}}"
NVIDIA_VISIBLE_DEVICES="${NVIDIA_VISIBLE_DEVICES:-all}"
NVIDIA_DRIVER_CAPABILITIES="${NVIDIA_DRIVER_CAPABILITIES:-compute,utility,video,graphics}"
SKIP_VULKAN_TEST=0

red='\033[0;31m'
green='\033[0;32m'
reset='\033[0m'

usage() {
  cat <<'EOF'
Usage:
  ./scripts/setup-debian-nvidia-ncnn.sh [options]

Options:
  --image IMAGE          ScrapeFun image used for the NCNN Vulkan smoke test.
                         Defaults to haoweil/scrapefun:latest.
  --skip-vulkan-test     Skip pulling and testing the ScrapeFun image.
  -h, --help             Show this help.

This script requires:
  - Debian with an already working NVIDIA host driver (nvidia-smi).
  - Docker installed and usable by the current user.

It installs NVIDIA Container Toolkit, configures the Docker runtime, restarts
Docker, verifies --gpus all, then runs a small NCNN/Vulkan inference in the
ScrapeFun image as the final UID 1000 application user. NVIDIA_VISIBLE_DEVICES
may be an index, UUID, comma-separated list, or all. Do not run the whole script
with sudo; it asks for sudo only when needed.
EOF
}

fail() {
  echo -e "${red}Error: $*${reset}" >&2
  exit 1
}

info() {
  echo -e "${green}==>${reset} $*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      [[ $# -ge 2 ]] || fail '--image requires an image name.'
      SCRAPEFUN_IMAGE="$2"
      shift 2
      ;;
    --skip-vulkan-test)
      SKIP_VULKAN_TEST=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

if [[ "${EUID}" -eq 0 ]]; then
  fail 'Run this script as the Docker user, not as root. It invokes sudo for host configuration.'
fi

command -v sudo >/dev/null 2>&1 || fail 'sudo is required for host configuration.'
command -v docker >/dev/null 2>&1 || fail 'Docker is not installed. Install Docker and Docker Compose first.'
command -v nvidia-smi >/dev/null 2>&1 || fail 'nvidia-smi is unavailable. Install the NVIDIA host driver and reboot before continuing.'

if ! docker info >/dev/null 2>&1; then
  fail 'The current user cannot access Docker. Add it to the docker group, sign in again, then retry.'
fi

if ! nvidia-smi -L >/dev/null 2>&1; then
  fail 'The NVIDIA host driver is not working. Fix nvidia-smi on the host before configuring Docker.'
fi

if [[ ! ",${NVIDIA_DRIVER_CAPABILITIES//[[:space:]]/}," == *,video,* \
  || ! ",${NVIDIA_DRIVER_CAPABILITIES//[[:space:]]/}," == *,graphics,* ]]; then
  fail 'NVIDIA_DRIVER_CAPABILITIES must include both video and graphics.'
fi

if [[ ! -r /etc/os-release ]]; then
  fail 'Cannot determine the operating system because /etc/os-release is missing.'
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != 'debian' ]]; then
  fail "This helper supports Debian only (detected: ${PRETTY_NAME:-unknown})."
fi

info "Detected ${PRETTY_NAME:-Debian}; NVIDIA driver is available:"
nvidia-smi -L

info 'Installing prerequisites and NVIDIA Container Toolkit'
sudo apt-get update
sudo apt-get install -y --no-install-recommends ca-certificates curl gnupg

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

curl -fsSL "${NVIDIA_GPG_KEY_URL}" | gpg --dearmor --yes --output "${tmp_dir}/nvidia-container-toolkit-keyring.gpg"
sudo install -D -m 0644 "${tmp_dir}/nvidia-container-toolkit-keyring.gpg" "${NVIDIA_KEYRING}"

curl -fsSL "${NVIDIA_SOURCE_LIST_URL}" \
  | sed "s#deb https://#deb [signed-by=${NVIDIA_KEYRING}] https://#g" \
  > "${tmp_dir}/nvidia-container-toolkit.list"
sudo install -D -m 0644 "${tmp_dir}/nvidia-container-toolkit.list" "${NVIDIA_SOURCE_LIST}"

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

if [[ -f /etc/docker/daemon.json ]]; then
  backup_path="/etc/docker/daemon.json.before-nvidia-ctk.$(date +%Y%m%d%H%M%S).bak"
  sudo cp -p /etc/docker/daemon.json "${backup_path}"
  info "Backed up Docker configuration to ${backup_path}"
fi

info 'Configuring the NVIDIA runtime for Docker'
sudo nvidia-ctk runtime configure --runtime=docker

if command -v systemctl >/dev/null 2>&1 && sudo systemctl restart docker; then
  :
elif command -v service >/dev/null 2>&1; then
  sudo service docker restart
else
  fail 'NVIDIA runtime was configured, but Docker could not be restarted automatically. Restart Docker, then rerun this script.'
fi

if ! docker info >/dev/null 2>&1; then
  fail 'Docker did not become available after restart. Inspect: sudo journalctl -u docker -n 100 --no-pager'
fi

info 'Verifying NVIDIA Container Toolkit with --gpus all'
docker run --rm --pull=missing --gpus all \
  -e "NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES}" \
  -e NVIDIA_DRIVER_CAPABILITIES=compute,utility \
  "${CUDA_TEST_IMAGE}" nvidia-smi -L

if [[ "${SKIP_VULKAN_TEST}" -eq 0 ]]; then
  info "Verifying that NCNN can see an NVIDIA Vulkan device in ${SCRAPEFUN_IMAGE}"
  vulkan_summary="$(docker run --rm --pull=missing --gpus all \
    -e "NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES}" \
    -e "NVIDIA_DRIVER_CAPABILITIES=${NVIDIA_DRIVER_CAPABILITIES}" \
    "${SCRAPEFUN_IMAGE}" \
    /bin/sh -lc 'test "$(id -u)" = 1000 && vulkaninfo --summary' 2>&1)" || {
      printf '%s\n' "${vulkan_summary}" >&2
      fail 'Vulkan could not start in the ScrapeFun image. Check NVIDIA_DRIVER_CAPABILITIES and the host driver.'
    }

  printf '%s\n' "${vulkan_summary}"
  if ! grep -Eqi 'deviceName[[:space:]]*=[[:space:]]*NVIDIA|GPU[0-9]+.*NVIDIA' <<<"${vulkan_summary}"; then
    fail 'Vulkan did not report an NVIDIA GPU. NCNN would fall back to CPU; do not deploy with GPU mode yet.'
  fi

  info 'Running a small Real-ESRGAN NCNN inference on Vulkan GPU 0'
  docker run --rm --pull=missing --gpus all \
    -e "NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES}" \
    -e "NVIDIA_DRIVER_CAPABILITIES=${NVIDIA_DRIVER_CAPABILITIES}" \
    "${SCRAPEFUN_IMAGE}" \
    /bin/sh -lc '
      set -eu
      test "$(id -u)" = 1000
      input=/tmp/ncnn-smoke-input.png
      output=/tmp/ncnn-smoke-output.png
      node -e "require(\"sharp\")({ create: { width: 16, height: 16, channels: 3, background: \"#808080\" } }).png().toFile(\"${input}\")"
      /app/server/vendor/linux/realesrgan-ncnn-vulkan-v0.2.0-linux/realesrgan-ncnn-vulkan \
        -i "${input}" \
        -o "${output}" \
        -s 2 \
        -n realesr-animevideov3-x2 \
        -m /app/server/vendor/linux/realesrgan-ncnn-vulkan-v0.2.0-linux/models \
        -g 0 \
        -t 32 \
        -j 1:1:1 \
        -v
      test -s "${output}"
    '
fi

echo
info 'NVIDIA Docker + Vulkan setup completed.'
echo 'Deploy ScrapeFun with NVIDIA passthrough:'
echo "  curl -fsSL https://raw.githubusercontent.com/ScrapeFun/ScrapeFun/main/scripts/one-click-compose-deploy.sh | SCRAPEFUN_GPU_MODE=nvidia NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES} bash"
echo 'During image enhancement, use: watch -n 0.5 nvidia-smi'
