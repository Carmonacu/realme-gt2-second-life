#!/data/data/com.termux/files/usr/bin/bash
# Ejecutar UNA vez en Termux (tras termux-setup-storage):
#   bash ~/storage/shared/Download/llm-setup/bootstrap.sh
set -euo pipefail

SETUP_DIR="${HOME}/storage/shared/Download/llm-setup"
REPO_FALLBACK="${HOME}/storage/shared/Download/llm-setup"

echo "=== Bootstrap LLM (RMX3311) ==="

if [[ ! -d "${HOME}/storage/shared" ]]; then
  echo "Falta acceso a almacenamiento. Ejecuta primero:"
  echo "  termux-setup-storage"
  echo "Acepta el permiso y vuelve a lanzar este script."
  exit 1
fi

if [[ ! -d "$SETUP_DIR" ]]; then
  echo "No existe $SETUP_DIR"
  echo "Desde el PC: adb push scripts/termux → /sdcard/Download/llm-setup/"
  exit 1
fi

echo "[1/6] Actualizando paquetes Termux..."
pkg update -y
pkg upgrade -y

echo "[2/6] Paquetes base (termux-tools incluye termux-wake-lock)..."
pkg install -y termux-tools curl

echo "[3/6] Instalando llama.cpp b12017 (benchmarks del dispositivo)..."
mkdir -p "${HOME}/opt/llama-b12017"
SRC_BIN="$SETUP_DIR/llama-b12017"
if [[ -x "$SRC_BIN/llama-server" ]]; then
  echo "  Copiando desde $SRC_BIN (puede tardar ~1 min)..."
  cp -a "$SRC_BIN/." "${HOME}/opt/llama-b12017/"
  chmod +x "${HOME}/opt/llama-b12017"/llama-server \
    "${HOME}/opt/llama-b12017"/llama-cli \
    "${HOME}/opt/llama-b12017"/llama-bench 2>/dev/null || true
else
  echo "  No hay binarios preempujados; probando pkg install llama-cpp..."
  pkg install -y llama-cpp || true
  if ! command -v llama-server >/dev/null 2>&1; then
    echo "  Compilando llama.cpp desde fuente (30–90 min en el teléfono)..."
    pkg install -y git cmake ninja clang make libandroid-spawn
    BUILD_DIR="${HOME}/src/llama.cpp"
    if [[ ! -d "$BUILD_DIR" ]]; then
      git clone --depth 1 https://github.com/ggml-org/llama.cpp "$BUILD_DIR"
    fi
    cmake -S "$BUILD_DIR" -B "$BUILD_DIR/build" -DCMAKE_BUILD_TYPE=Release \
      -DGGML_CPU_ARM_ARCH=armv8.2-a+dotprod \
      -DLLAMA_CURL=ON \
      -DLLAMA_BUILD_SERVER=ON \
      -DLLAMA_SUBPROCESS=ON   # router de llama-server (OFF por defecto en Android)
    cmake --build "$BUILD_DIR/build" -j"$(nproc)"
    mkdir -p "${HOME}/opt/llama-b12017"
    cp -a "$BUILD_DIR/build/bin/"* "${HOME}/opt/llama-b12017/" 2>/dev/null || \
      cp -a "$BUILD_DIR/build/"* "${HOME}/opt/llama-b12017/" 2>/dev/null || true
  fi
fi

if [[ -x "${HOME}/opt/llama-b12017/llama-server" ]]; then
  export LD_LIBRARY_PATH="${HOME}/opt/llama-b12017${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  echo "  llama-server: $("${HOME}/opt/llama-b12017/llama-server" --version 2>&1 | head -1 || true)"
elif command -v llama-server >/dev/null 2>&1; then
  echo "  llama-server (pkg): $(llama-server --version 2>&1 | head -1 || true)"
else
  echo "ERROR: no se pudo instalar llama-server." >&2
  exit 1
fi

echo "[4/6] Modelos GGUF (copia rápida a almacenamiento Termux)..."
MODEL_SRC="${HOME}/storage/shared/Download/llm-models"
MODEL_NATIVE="${HOME}/models"
mkdir -p "$MODEL_SRC"
if [[ -L "$MODEL_NATIVE" ]]; then
  rm -f "$MODEL_NATIVE"
fi
mkdir -p "$MODEL_NATIVE"
shopt -s nullglob
ggufs=( "$MODEL_SRC"/*.gguf )
if [[ ${#ggufs[@]} -eq 0 ]]; then
  echo "  Aviso: no hay .gguf en $MODEL_SRC (adb push desde PC)."
else
  for src in "${ggufs[@]}"; do
    base="$(basename "$src")"
    dst="$MODEL_NATIVE/$base"
    if [[ -f "$dst" ]] && [[ "$(stat -c%s "$dst" 2>/dev/null || stat -f%z "$dst" 2>/dev/null || echo 0)" == "$(stat -c%s "$src" 2>/dev/null || stat -f%z "$src" 2>/dev/null || echo 1)" ]]; then
      echo "  OK (ya copiado): $base"
    else
      echo "  Copiando $base → $MODEL_NATIVE (mmap nativo, puede tardar varios min)..."
      cp -f "$src" "$dst"
    fi
  done
fi
ln -sfn "$MODEL_SRC" "${HOME}/models-sdcard"
echo "  Inferencia: $MODEL_NATIVE | copia SD: $MODEL_SRC"

echo "[5/6] Scripts en ~/bin..."
mkdir -p "${HOME}/bin"
for f in llm llm-common.sh run-smol.sh run-qwen3b.sh run-qwen05.sh run-ds15.sh run-phi.sh run-router.sh run-qwen3b-spec.sh mode mode-lib.sh kali kali-common.sh power-lib.sh charge-limiter thermal-guard; do
  if [[ -f "$SETUP_DIR/$f" ]]; then
    cp "$SETUP_DIR/$f" "${HOME}/bin/$f"
    chmod +x "${HOME}/bin/$f"
  fi
done

grep -q 'export PATH=.*\$HOME/bin' "${HOME}/.bashrc" 2>/dev/null || {
  echo 'export PATH="$HOME/bin:$PATH"' >> "${HOME}/.bashrc"
}

echo "[6/6] termux.properties (opcional: adb RUN_COMMAND)..."
mkdir -p "${HOME}/.termux"
PROP="${HOME}/.termux/termux.properties"
if [[ -f "$PROP" ]] && grep -q 'allow-external-apps' "$PROP"; then
  sed -i 's/^#*allow-external-apps=.*/allow-external-apps=true/' "$PROP" 2>/dev/null || \
    grep -q 'allow-external-apps=true' "$PROP" || echo 'allow-external-apps=true' >> "$PROP"
else
  echo 'allow-external-apps=true' >> "$PROP"
fi

echo ""
echo "=== Listo ==="
echo "Modelos (Termux): $MODEL_NATIVE"
ls -lh "$MODEL_NATIVE"/*.gguf 2>/dev/null || echo "  (ningún .gguf — mueve desde PC con adb)"
echo ""
echo "Arrancar chat (navegador → http://127.0.0.1:8080):"
echo "  source ~/.bashrc   # o abre nueva sesión Termux"
echo "  llm smol"
echo ""
echo "ColorOS: Ajustes → Opciones de desarrollador → Desactivar restricciones de procesos hijo"
echo "Guía: docs/termux-llm-guide.md (en el repo del PC)"
