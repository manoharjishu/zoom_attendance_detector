#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${ROOT_DIR}/.venv"
PYTHON_BIN="${PYTHON_BIN:-python3}"

print_step() {
  printf '\n[%s] %s\n' "setup" "$1"
}

print_step "Project root: ${ROOT_DIR}"

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "Error: ${PYTHON_BIN} not found. Install Python 3.10+ and retry." >&2
  exit 1
fi

print_step "Python version"
"${PYTHON_BIN}" --version

if [ ! -d "${VENV_DIR}" ]; then
  print_step "Creating virtual environment at ${VENV_DIR}"
  "${PYTHON_BIN}" -m venv "${VENV_DIR}"
else
  print_step "Virtual environment already exists at ${VENV_DIR}"
fi

print_step "Upgrading pip/setuptools/wheel (optional)"
if "${VENV_DIR}/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1; then
  echo "Upgrade complete."
else
  echo "Skipped package upgrade (offline or restricted network)."
fi

print_step "Installing required dependencies"
"${VENV_DIR}/bin/pip" install -q pytesseract pillow numpy opencv-python 2>/dev/null || {
  echo "Warning: Failed to install some dependencies. You may need to install them manually."
}

print_step "Making scripts executable"
chmod +x "${ROOT_DIR}/zoom_attendance_detector.py"

print_step "Sanity check (syntax compile)"
"${VENV_DIR}/bin/python" -m py_compile "${ROOT_DIR}/zoom_attendance_detector.py"

cat <<EOF

Setup complete.

Dependencies installed:
  - pytesseract (OCR text recognition)
  - pillow (image handling)
  - numpy (numerical computation)
  - opencv-python (computer vision)

Use in any IDE terminal:
  source .venv/bin/activate

Run GUI app:
  python zoom_attendance_detector.py

Run CLI mode:
  python zoom_attendance_detector.py

Note: On macOS, you'll need Tesseract OCR:
  brew install tesseract

EOF
