# Zoom Attendance Detector

A tool to detect Zoom attendance polling popups and alert you when they appear. Uses computer vision and OCR to identify the "Please mark your attendance" popup in Zoom meetings.

## Features

- **Automated Popup Detection**: Monitors your screen for Zoom attendance polls
- **Audio Alerts**: Plays alert sounds at configurable intervals
- **GUI & CLI Modes**: Use the graphical interface or command-line interface
- **Cross-platform**: Works on macOS and Windows
- **OCR-based**: Uses Tesseract OCR for accurate text detection

## Quick Start

```bash
./setup.sh
source .venv/bin/activate
python zoom_attendance_detector.py
```

## Requirements

- Python 3.10+
- Tesseract OCR

### macOS Setup

```bash
brew install tesseract
./setup.sh
source .venv/bin/activate
python zoom_attendance_detector.py
```

### Windows Setup

1. Install Tesseract from: https://github.com/UB-Mannheim/tesseract/wiki
2. Update the `pytesseract.pytesseract.tesseract_cmd` path in `zoom_attendance_detector.py`
3. Run `./setup.sh` and activate the virtual environment

## Usage

### GUI Mode
```bash
python zoom_attendance_detector.py
```

The application opens a Tkinter window with:
- **Start**: Begin monitoring for attendance polls
- **Stop**: Stop monitoring
- **Quit**: Close the application
- **Log**: Real-time detection logs

### CLI Mode
```bash
python zoom_attendance_detector.py

# Interactive menu:
# 1 → Start Detection
# 2 → Stop Detection
# q → Quit
```

## How It Works

1. **Screen Capture**: Continuously captures screenshots of your screen
2. **Region Detection**: Monitors the Zoom popup region (upper-middle area)
3. **Visual Change Detection**: Detects significant visual changes indicating a popup
4. **OCR Confirmation**: Extracts text from the popup area to confirm it's an attendance poll
5. **Alert Trigger**: Plays audio alerts when "kindly mark your attendance" is detected

## Configuration

Edit `zoom_attendance_detector.py` to customize:

- `ALERT_INTERVAL`: Time between repeated alerts (default: 10 seconds)
- Popup region coordinates in `detect_loop()`: `popup_y1`, `popup_y2`, `popup_x1`, `popup_x2`

## Troubleshooting

**"Tesseract not found" error**: Install Tesseract OCR
- macOS: `brew install tesseract`
- Windows: Download from https://github.com/UB-Mannheim/tesseract/wiki

**Audio not playing**: Ensure `alert.aiff` is in the project directory

**Detection not working**: Try adjusting the popup region coordinates or increasing the `ALERT_INTERVAL`

## Notes

- This tool monitors your entire screen. Use responsibly.
- It requires desktop permissions to capture screenshots.
- Works best when Zoom is in windowed mode (not fullscreen).

## License

This project is part of the TimesPro toolset.
