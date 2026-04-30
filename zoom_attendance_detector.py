import sys
import pytesseract
from PIL import ImageGrab
import threading
import time
import os
import numpy as np
import cv2
import tkinter as tk

# 🟢 SET TESSERACT PATH (Windows users update this)
# Windows example:
# pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

ALERT_INTERVAL = 10
running = False
status_var = None
status_label = None
log_text = None


def append_log(message):
    global log_text
    print(message)
    if log_text is not None:
        log_text.config(state='normal')
        log_text.insert('end', message + '\n')
        log_text.see('end')
        log_text.config(state='disabled')


def set_status(message, fg='black'):
    append_log(message)
    global status_var, status_label
    if status_var is not None:
        status_var.set(message)
    if status_label is not None:
        status_label.config(fg=fg)


# 🔊 Voice alert (Mac + Windows)
def play_sound():
    if os.name == "nt":
        os.system('powershell -c "(New-Object -ComObject SAPI.SpVoice).Speak(\'Please mark your attendance\')"')
        return

    if getattr(sys, 'frozen', False):
        audio_path = os.path.join(sys._MEIPASS, 'alert.aiff')
    else:
        audio_path = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'alert.aiff'))

    if os.path.exists(audio_path):
        os.system(f'afplay "{audio_path}"')
    else:
        print('Audio file not found:', audio_path)
        os.system('say "Please mark attendance"')


# 🎯 Capture full screen (simpler + more reliable)
def get_screen():
    screenshot = ImageGrab.grab()
    return np.array(screenshot)


def detect_loop():
    global running

    print("Detect loop started")
    prev_frame = None
    alert_active = False
    last_alert_time = 0
    missed_frames = 0

    while running:
        try:
            frame = get_screen()
            gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)

            if prev_frame is None:
                prev_frame = gray
                time.sleep(2)
                continue

            h, w = gray.shape

            # 🔍 Only watch the Zoom popup region: upper-middle area where poll dialogs appear.
            popup_y1, popup_y2 = int(h * 0.15), int(h * 0.45)
            popup_x1, popup_x2 = int(w * 0.25), int(w * 0.75)
            popup_area = gray[popup_y1:popup_y2, popup_x1:popup_x2]

            # Detect visual changes only inside the popup region.
            diff = cv2.absdiff(prev_frame[popup_y1:popup_y2, popup_x1:popup_x2], popup_area)
            change = np.sum(diff) / diff.size

            print("Change level:", change, "popup region", (popup_y1, popup_y2, popup_x1, popup_x2))

            # 🎯 Step 1: Detect visual popup
            popup_detected = change > 4 or alert_active

            # 🎯 Step 2: OCR confirmation on the popup area only
            text = pytesseract.image_to_string(popup_area, config='--psm 6').lower()
            print("OCR:", repr(text[:120]))

            # STRICT condition
            poll_detected = (
                popup_detected and
                "kindly mark your" in text and
                "attendance" in text
            )

            current_time = time.time()

            if poll_detected:
                if not alert_active:
                    set_status("✅ Poll detected — listening for Zoom popup", fg='green')
                    alert_active = True
                    play_sound()
                    last_alert_time = current_time
                elif current_time - last_alert_time > ALERT_INTERVAL:
                    play_sound()
                    last_alert_time = current_time
            else:
                if alert_active:
                    set_status("❌ Popup gone, stopping alerts", fg='orange')
                alert_active = False

            prev_frame = gray
            time.sleep(2)

        except Exception as e:
            set_status(f"Error: {e}", fg='red')
            time.sleep(5)

def start():
    global running
    if not running:
        running = True
        threading.Thread(target=detect_loop, daemon=True).start()
        print("🟢 Detection started")


def stop():
    global running
    running = False
    print("🔴 Detection stopped")


def run_gui():
    global status_var, status_label, log_text
    root = tk.Tk()
    root.title("Zoom Poll Detector")
    root.geometry("360x320")
    root.resizable(False, False)

    title = tk.Label(root, text="Zoom Poll Detector", font=("Helvetica", 14, "bold"))
    title.pack(pady=(12, 4))

    status_var = tk.StringVar(value="Stopped")
    status_label = tk.Label(root, textvariable=status_var, fg="red", font=("Helvetica", 11))
    status_label.pack(pady=(0, 8))

    def start_app():
        start()
        status_var.set("Running")
        status_label.config(fg="green")

    def stop_app():
        stop()
        status_var.set("Stopped")
        status_label.config(fg="red")

    start_button = tk.Button(root, text="Start", width=12, command=start_app)
    stop_button = tk.Button(root, text="Stop", width=12, command=stop_app)
    quit_button = tk.Button(root, text="Quit", width=12, command=root.destroy)

    start_button.pack(pady=(0, 6))
    stop_button.pack(pady=(0, 6))
    quit_button.pack(pady=(0, 6))

    log_frame = tk.Frame(root)
    log_frame.pack(fill='both', expand=True, padx=12, pady=(8, 12))

    log_scroll = tk.Scrollbar(log_frame)
    log_scroll.pack(side='right', fill='y')

    log_text = tk.Text(log_frame, height=8, width=42, state='disabled', wrap='word', bg='#f7f7f7')
    log_text.pack(side='left', fill='both', expand=True)
    log_text.config(yscrollcommand=log_scroll.set)
    log_scroll.config(command=log_text.yview)

    def on_close():
        stop()
        root.destroy()

    root.protocol("WM_DELETE_WINDOW", on_close)
    root.mainloop()


if __name__ == "__main__":
    if getattr(sys, 'frozen', False):
        run_gui()
    else:
        # CLI mode
        print("\n=== Zoom Poll Detector ===")
        print("1 → Start Detection")
        print("2 → Stop Detection")
        print("q → Quit")

        while True:
            cmd = input("Enter: ").strip()

            if cmd == "1":
                start()
            elif cmd == "2":
                stop()
            elif cmd.lower() == "q":
                stop()
                break
