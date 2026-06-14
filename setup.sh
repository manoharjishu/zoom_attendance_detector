#!/bin/bash

set -e

echo "========================================="
echo " Starting Zoom Attendance Detector Setup "
echo "========================================="

# ---------------------------------------------------------------------
# 1. DETECT OPERATING SYSTEM
# ---------------------------------------------------------------------
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
    echo "✔ Detected Operating System: macOS"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="Windows"
    echo "✔ Detected Operating System: Windows (Git Bash)"
else
    echo "❌ Unsupported Operating System: $OSTYPE"
    exit 1
fi

echo "-----------------------------------------"

# Helper paths for Windows pre-checks
TESSERACT_WIN_PATH="/c/Program Files/Tesseract-OCR"

# ---------------------------------------------------------------------
# FUNCTION: Install and Configure for macOS
# ---------------------------------------------------------------------
install_mac() {
    if ! command -v brew &> /dev/null; then
        echo "⏳ Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    if command -v python3 &> /dev/null; then
        echo "✔ Python 3 is already installed. Skipping installation."
    else
        echo "⏳ Installing Python via Homebrew..."
        brew install python
    fi

    if command -v tesseract &> /dev/null; then
        echo "✔ Tesseract is already installed. Skipping installation."
    else
        echo "⏳ Installing Tesseract via Homebrew..."
        brew install tesseract
    fi

    export PATH="/opt/homebrew/bin:$PATH"
}

# ---------------------------------------------------------------------
# FUNCTION: Install and Configure for Windows
# ---------------------------------------------------------------------
install_windows() {
    if command -v python &> /dev/null || command -v python3 &> /dev/null || [ -d "/c/Users/$USER/AppData/Local/Programs/Python" ]; then
        echo "✔ Python installation detected. Skipping installer link."
    else
        echo "================================================================================"
        echo "🌐 PYTHON REQUIRED"
        echo "Please open your browser and download the latest stable installer from:"
        echo "👉 https://www.python.org/downloads/"
        echo ""
        echo "🚨 CRITICAL DIRECTION DURING INSTALLATION:"
        echo "   You MUST check the box that says 'Add python.exe to PATH'"
        echo "   at the bottom of the installation wizard window before clicking 'Install Now'!"
        echo "================================================================================"
        
        read -p "Press [Enter] ONLY AFTER you have fully installed Python on your machine..." < /dev/tty
    fi
    
    if command -v tesseract &> /dev/null || [ -d "$TESSERACT_WIN_PATH" ]; then
        echo "✔ Tesseract OCR directory or command detected. Skipping download."
    else
        echo "⏳ Updating winget source catalogs for Tesseract..."
        winget source update || true
        
        echo "⏳ Installing Tesseract OCR via winget..."
        if ! winget install --id UB.TesseractOCR --source winget --silent --accept-source-agreements --accept-package-agreements; then
            echo "⚠️ winget failed to install Tesseract automatically."
            echo "👉 Please manually download the Tesseract installer from:"
            echo "   https://github.com/UB-Mannheim/tesseract/wiki"
            echo "--------------------------------------------------------------------------------"
            read -p "Press [Enter] ONLY AFTER you have completed the manual Tesseract installation..." < /dev/tty
        fi
    fi
    
    if [ -d "$TESSERACT_WIN_PATH" ]; then
        echo "⏳ Injecting Tesseract into environment configuration..."
        export PATH="$PATH:$TESSERACT_WIN_PATH"
        
        powershell.exe -Command "
            \$currentPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::User);
            if (\$currentPath -notlike '*Tesseract-OCR*') {
                [Environment]::SetEnvironmentVariable('Path', \$currentPath + ';C:\Program Files\Tesseract-OCR', [EnvironmentVariableTarget]::User);
                Write-Output '✔ Permanently updated Windows User PATH for Tesseract.';
            }
        "
    fi
}

# ---------------------------------------------------------------------
# FUNCTION: Build & Verify Environment Variables
# ---------------------------------------------------------------------
verify_and_build_env() {
    local max_attempts=2
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        echo "⏳ Verifying environment paths (Attempt $attempt/$max_attempts)..."
        
        if [ "$OS" == "Windows" ]; then
            export PATH="$PATH:$TESSERACT_WIN_PATH"
            for py_dir in /c/Users/$USER/AppData/Local/Programs/Python/Python*; do
                if [ -d "$py_dir" ]; then
                    export PATH="$PATH:$py_dir"
                    export PATH="$PATH:$py_dir/Scripts"
                fi
            done

            if [ -d "/c/Users/$USER/AppData/Local/Microsoft/WindowsApps" ]; then
                export PATH=$(echo "$PATH" | sed -e 's|/c/Users/[^/]*/AppData/Local/Microsoft/WindowsApps||g')
            fi
        fi

        PYTHON_OK=true
        TESSERACT_OK=true

        if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
            PYTHON_OK=false
        fi

        if ! command -v tesseract &> /dev/null; then
            TESSERACT_OK=false
        fi

        if [ "$PYTHON_OK" = true ] && [ "$TESSERACT_OK" = true ]; then
            echo "✔ Environment dependencies validated and active."
            return 0
        fi

        if [ $attempt -lt $max_attempts ]; then
            echo "❌ Path alignment failed. Re-checking paths..."
            if [ "$OS" == "macOS" ]; then
                brew link --overwrite tesseract || true
            else
                install_windows
            fi
        fi
        
        ((attempt++))
    done

    echo "❌ Environment build failed. Tesseract or Python is still missing from PATH."
    exit 1
}

# ---------------------------------------------------------------------
# MAIN EXECUTION FLOW
# ---------------------------------------------------------------------

if [ "$OS" == "macOS" ]; then
    install_mac
else
    install_windows
fi

verify_and_build_env

# Setup/Activate Virtual Environment cleanly
echo "⏳ Setting up local project virtual environment (venv)..."
if command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    PYTHON_CMD="python3"
fi

if [ "$OS" == "Windows" ]; then
    # Force fresh environment generation if previous was partially created
    if [ -d "venv" ]; then
        rm -rf venv
    fi
    $PYTHON_CMD -m venv venv --copies
else
    $PYTHON_CMD -m venv venv
fi

source venv/Scripts/activate 2>/dev/null || source venv/bin/activate

# --- REQUIREMENTS AND PACKAGE INSTALLATION LAYER ---
echo "⏳ Processing Python library dependencies inside venv..."

# Upgrade local pip version safely using module execution
python -m pip install --upgrade pip --quiet || python3 -m pip install --upgrade pip --quiet || true

# --- FIX: Overwrite/Create requirements.txt with Python 3.13 compliant versions ---
echo "⏳ Writing structural version tracking for requirements.txt..."
cat << EOF > requirements.txt
pytesseract==0.3.13
Pillow>=10.4.0
opencv-python>=4.10.0.84
pandas>=2.2.3
numpy>=2.1.0
EOF

echo "⏳ Executing requirement catalog matrix installation..."
pip install -r requirements.txt

# 4. FINAL SUCCESS MESSAGE
echo "========================================="
echo " 🎉 SUCCESS: Setup Completed Successfully! "
echo "========================================="
echo "• OS Target: $OS"
echo "• Python version: $($PYTHON_CMD --version)"
echo "• Tesseract version: $(tesseract --version | head -n 1)"
echo "• Environment File Check: Verified (Python 3.13 compatible layout)"
echo "-----------------------------------------"
echo "Your environment is fully initialized. Run your app via:"
echo "python zoom_attendance_detector.py"
echo "========================================="