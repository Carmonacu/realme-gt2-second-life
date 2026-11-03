#!/data/data/com.termux/files/usr/bin/bash
# Descarga torrentio.yml al folder Custom de Prowlarr (Cardigann).
set -euo pipefail

MEDIA_ARR="${HOME}/media-arr"
PROWLARR_DATA="${MEDIA_ARR}/config/prowlarr"
CUSTOM="${PROWLARR_DATA}/Definitions/Custom"
# master aún usa infohash→url (falla validación); fijado al fix PR #93
TORRENTIO_YML_COMMIT="5ac2b0cec728a5f247972b7677347b419bb338cd"
RAW_BASE="https://raw.githubusercontent.com/dreulavelle/Prowlarr-Indexers/${TORRENTIO_YML_COMMIT}/Custom"

mkdir -p "$CUSTOM"

fetch_one() {
  local name="$1"
  local url="${RAW_BASE}/${name}"
  local out="${CUSTOM}/${name}"
  echo "==> ${name}"
  curl -fsSL --retry 3 -o "${out}.tmp" "$url"
  mv -f "${out}.tmp" "$out"
  echo "    -> ${out}"
}

if ! fetch_one "torrentio.yml" 2>/dev/null; then
  echo "    aviso: torrentio.yml no en Custom/ — busca en dreulavelle/Prowlarr-Indexers" >&2
  exit 1
fi

# Copia legacy (script antiguo) — Prowlarr no la lee ahí
rm -f "${PROWLARR_DATA}/torrentio.yml" 2>/dev/null || true

echo ""
echo "Prowlarr lee YML en: ${CUSTOM}/"
echo "  1) Reinicia Prowlarr o espera ~1 min (caché de definiciones)."
echo "  2) Indexers → Add Indexer → busca «Torrentio» (o el nombre del YML)."
echo "  3) Si no aparece: System → Restart Prowlarr, vuelve a Add Indexer."
