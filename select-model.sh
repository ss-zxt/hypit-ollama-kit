#!/usr/bin/env bash
# select-model.sh — pick the qwen3 size that fits THIS machine.
#
# Prints exactly one model tag on stdout (e.g. qwen3:8b); the reasoning goes
# to stderr so callers can do:  MODEL="$(bash select-model.sh)"
#
# Tier logic (the model must fit in VRAM when a GPU exists, else in RAM,
# with room left for the OS, Hypit's Chrome and the context window):
#   VRAM >= 16 GB  or  RAM >= 32 GB   -> qwen3:14b  (~9.3 GB download)
#   VRAM >=  8 GB  or  RAM >= 16 GB   -> qwen3:8b   (~5.2 GB)
#   RAM  >=  8 GB                     -> qwen3:4b   (~2.5 GB)
#   otherwise                         -> qwen3:1.7b (~1.4 GB, the safe floor)
#
# Test hooks (not for production): KIT_FAKE_RAM_GB, KIT_FAKE_VRAM_GB override
# the detected values so the tiers can be exercised on any machine.
set -Eeuo pipefail

RAM_GB="${KIT_FAKE_RAM_GB:-}"
if [ -z "$RAM_GB" ]; then
  MEM_KB="$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || echo 0)"
  # Round to the NEAREST GiB: a nominal "8 GB" server reports ~7.9 GiB of
  # MemTotal, and flooring would wrongly drop it into the 1.7b tier.
  RAM_GB=$(( (MEM_KB + 524288) / 1048576 ))
fi

VRAM_GB="${KIT_FAKE_VRAM_GB:-0}"
if [ -z "${KIT_FAKE_VRAM_GB:-}" ] && command -v nvidia-smi >/dev/null 2>&1; then
  VRAM_MB="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | sort -rn | head -1 || echo 0)"
  VRAM_GB=$(( ${VRAM_MB:-0} / 1024 ))
fi

MODEL="qwen3:1.7b"; REASON="floor tier: safe on any supported machine"
if [ "$VRAM_GB" -ge 16 ] || [ "$RAM_GB" -ge 32 ]; then
  MODEL="qwen3:14b"; REASON="high tier: VRAM ${VRAM_GB} GB / RAM ${RAM_GB} GB"
elif [ "$VRAM_GB" -ge 8 ] || [ "$RAM_GB" -ge 16 ]; then
  MODEL="qwen3:8b"; REASON="mid-high tier: VRAM ${VRAM_GB} GB / RAM ${RAM_GB} GB"
elif [ "$RAM_GB" -ge 8 ]; then
  MODEL="qwen3:4b"; REASON="mid tier: RAM ${RAM_GB} GB"
fi

echo "detected: RAM ${RAM_GB} GB, GPU VRAM ${VRAM_GB} GB -> $MODEL ($REASON)" >&2
echo "$MODEL"
