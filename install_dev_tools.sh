#!/usr/bin/env bash
# =============================================================================
# install_dev_tools.sh
# Automates setup of a DevOps + ML development environment.
# Idempotent — safe to run multiple times.
#
# Installs / checks:
#   Docker, Docker Compose, Python ≥ 3.9, pip
#   Python libs: torch, torchvision, pillow, Django
#
# Bonus: logs all output + versions to install.log
# =============================================================================

set -euo pipefail          # exit on error, unset var, or pipe failure

# ── Logging setup ─────────────────────────────────────────────────────────────
LOG_FILE="install.log"
exec > >(tee -a "$LOG_FILE") 2>&1   # tee every line to log AND terminal

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*"; }
warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $*"; }
ok()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OK]    $*"; }
err()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*"; exit 1; }

log "========== install_dev_tools.sh started =========="

# ── Helper: check if a command exists ────────────────────────────────────────
is_installed() { command -v "$1" &>/dev/null; }

# ── Helper: compare semver strings (returns 0 if $1 >= $2) ──────────────────
version_gte() {
    # Usage: version_gte "3.10.1" "3.9"
    python3 - "$1" "$2" <<'EOF'
import sys
from packaging.version import Version
v1, v2 = sys.argv[1], sys.argv[2]
sys.exit(0 if Version(v1) >= Version(v2) else 1)
EOF
}

# =============================================================================
# 1. DOCKER
# =============================================================================
log "── Checking Docker ──────────────────────────────────────────────────────"

if is_installed docker; then
    ok "Docker already installed: $(docker --version)"
else
    warn "Docker not found — installing..."

    # Official Docker install script (works on Ubuntu/Debian)
    if is_installed curl; then
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh
        rm /tmp/get-docker.sh
    else
        err "curl is required to install Docker. Run: sudo apt-get install -y curl"
    fi

    # Allow current user to run docker without sudo
    sudo usermod -aG docker "$USER" || true
    ok "Docker installed: $(docker --version)"
fi

# =============================================================================
# 2. DOCKER COMPOSE
# =============================================================================
log "── Checking Docker Compose ──────────────────────────────────────────────"

if docker compose version &>/dev/null 2>&1; then
    ok "Docker Compose (plugin) already installed: $(docker compose version)"
elif is_installed docker-compose; then
    ok "Docker Compose (standalone) already installed: $(docker-compose --version)"
else
    warn "Docker Compose not found — installing plugin..."
    sudo apt-get update -qq
    sudo apt-get install -y docker-compose-plugin
    ok "Docker Compose installed: $(docker compose version)"
fi

# =============================================================================
# 3. PYTHON ≥ 3.9
# =============================================================================
log "── Checking Python ≥ 3.9 ───────────────────────────────────────────────"

PYTHON_MIN="3.9"
PYTHON_BIN=""

# Try python3 first, then python
for bin in python3 python; do
    if is_installed "$bin"; then
        PY_VER=$("$bin" --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)
        if version_gte "$PY_VER" "$PYTHON_MIN" 2>/dev/null; then
            PYTHON_BIN="$bin"
            ok "Python $PY_VER already installed at $(command -v $bin)"
            break
        fi
    fi
done

if [[ -z "$PYTHON_BIN" ]]; then
    warn "Python ≥ $PYTHON_MIN not found — installing python3.11 via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y python3.11 python3.11-venv python3.11-distutils
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
    PYTHON_BIN="python3.11"
    ok "Python installed: $($PYTHON_BIN --version)"
fi

# =============================================================================
# 4. PIP
# =============================================================================
log "── Checking pip ─────────────────────────────────────────────────────────"

if is_installed pip || is_installed pip3; then
    PIP_BIN=$(is_installed pip && echo pip || echo pip3)
    ok "pip already installed: $($PIP_BIN --version)"
else
    warn "pip not found — installing..."
    sudo apt-get update -qq
    sudo apt-get install -y python3-pip
    ok "pip installed: $(pip3 --version)"
fi

# Use pip3 going forward
PIP_CMD="$PYTHON_BIN -m pip"

# =============================================================================
# 5. PYTHON LIBRARIES
# =============================================================================
log "── Checking / Installing Python libraries ───────────────────────────────"

install_python_pkg() {
    local pkg="$1"
    local import_name="${2:-$1}"   # some packages have different import names

    # Check if importable
    if $PYTHON_BIN -c "import ${import_name}" &>/dev/null 2>&1; then
        local ver
        ver=$($PYTHON_BIN -c "import ${import_name}; print(getattr(${import_name}, '__version__', 'unknown'))" 2>/dev/null || echo "unknown")
        ok "${pkg} already installed (version: ${ver})"
    else
        warn "${pkg} not found — installing..."
        $PIP_CMD install --upgrade "$pkg"
        ok "${pkg} installed successfully"
    fi
}

install_python_pkg "torch"
install_python_pkg "torchvision"
install_python_pkg "pillow"       "PIL"
install_python_pkg "Django"       "django"

# =============================================================================
# 6. VERSION SUMMARY  (Bonus)
# =============================================================================
log "── Version Summary ──────────────────────────────────────────────────────"

{
    echo "===== Version Report — $(date) ====="
    echo ""
    echo "Docker:         $(docker --version 2>/dev/null || echo 'NOT FOUND')"
    echo "Docker Compose: $(docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo 'NOT FOUND')"
    echo "Python:         $($PYTHON_BIN --version 2>/dev/null || echo 'NOT FOUND')"
    echo "pip:            $($PIP_CMD --version 2>/dev/null || echo 'NOT FOUND')"
    echo ""
    echo "Python packages:"
    $PYTHON_BIN -c "
import torch, torchvision, PIL, django
print(f'  torch        {torch.__version__}')
print(f'  torchvision  {torchvision.__version__}')
print(f'  pillow       {PIL.__version__}')
print(f'  Django       {django.__version__}')
" 2>/dev/null || echo "  (could not import one or more packages)"
    echo ""
    echo "==============================================="
} | tee -a "$LOG_FILE"

log "========== install_dev_tools.sh finished — log saved to $LOG_FILE ======="