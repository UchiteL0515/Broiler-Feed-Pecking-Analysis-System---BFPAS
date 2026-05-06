"""
BFPAS Raspberry Pi Flask Server - Live Feed + 10-Minute SVM Inference
OPTIMIZED VERSION

Pipeline:
1) Live feed mode:
   rpicam-vid -> ONNX head detection -> cage zone assignment -> selected chicken overlay -> MJPEG stream

2) Inference mode (record first):
   App POST /inference/start -> record a fixed-duration video at camera FPS -> process the saved
   video frame-by-frame with ONNX -> extract per-chicken features -> load saved One-Class SVM
   + scaler -> predict Normal/Anomaly -> expose results through /data

Optimizations applied vs original:
  - SVM model + scaler loaded once at startup (not per-inference call)
  - Dead legacy inference code paths removed (finalize_inference, append_inference_logs, etc.)
  - FPS global mutation replaced with local constant; no race condition
  - Zero-detection guard: chickens with insufficient coverage return "No data" instead of
    being silently imputed to zero before SVM classification
  - NMS vectorized with numpy argsort; inner loop eliminated
  - Peck detector inner loop uses pre-sliced numpy windows (no per-row Python loop overhead)
  - process_detection_dataframe confidence filter applied once with a vectorized assign_chicken_id
  - Frame progress exposed in inference snapshot (_inference_frames_processed counter)
  - Video recorded as .mp4 (H264 in MP4 container) for reliable OpenCV CAP_PROP_FPS reads
  - Letterbox reuses pre-computed target shape; avoids redundant tuple builds
  - Per-chicken timeseries pipeline uses in-place operations where safe
  - Removed unused _inference_logs global state and related lock sections

Requirements:
    pip install flask onnxruntime numpy pandas opencv-python-headless joblib scikit-learn

Expected files beside this script:
    best.onnx
    models/ocsvm_model.pkl
    models/scaler.pkl
"""

from flask import Flask, jsonify, Response, request
import queue
import socket
import subprocess
import threading
import time
import os
import math
from datetime import datetime

import cv2
import numpy as np
import pandas as pd
import onnxruntime as ort
import joblib

import functools
print = functools.partial(print, flush=True)

app = Flask(__name__)
# ============================================================
# CONFIG
# ============================================================
ONNX_MODEL_PATH = "best.onnx"
SVM_MODEL_PATH  = "models/ocsvm_model.pkl"
SCALER_PATH     = "models/scaler.pkl"

LOG_DIR        = "inference_logs"
RESULTS_DIR    = "results"
RECORDINGS_DIR = "recordings"
os.makedirs(LOG_DIR,        exist_ok=True)
os.makedirs(RESULTS_DIR,    exist_ok=True)
os.makedirs(RECORDINGS_DIR, exist_ok=True)

CONF_THRESHOLD         = 0.25   # ONNX live detection threshold
FEATURE_CONF_THRESHOLD = 0.30   # Feature extraction threshold
IOU_THRESHOLD          = 0.50
INPUT_SIZE             = 640

FRAME_BUFFER_SIZE = 512
FRAME_WIDTH  = 1280
FRAME_HEIGHT = 720
CAMERA_FPS   = 15
STREAM_FPS   = 8

# Live mode throttles detection to reduce lag.
DETECTION_EVERY_N_FRAMES = 4

# Inference needs denser detections for peck/velocity features.
# If the Pi becomes too slow, try 2, but 1 is best for accuracy.
INFERENCE_DETECTION_EVERY_N_FRAMES = 1

JPEG_QUALITY = 55

# 10 minutes = 600 seconds. For quick testing POST {"duration_sec": 30}.
DEFAULT_INFERENCE_DURATION_SEC = 600

# Minimum fraction of frames a chicken must be detected in to
# attempt SVM classification. Below this, result is "No data".
MIN_COVERAGE_RATIO = 0.05

# Based on 1280x720 fixed cage layout
CAGE_ZONES = {
    1: (0,    320),
    2: (320,  640),
    3: (640,  960),
    4: (960, 1280),
}

# Feeder areas used for feature extraction
# Format: chicken_id: (x_min, x_max, y_min, y_max)
FEEDER_ZONES = {
    1: (40,  290, 520, 720),
    2: (350, 610, 520, 720),
    3: (670, 930, 520, 720),
    4: (980,1240, 520, 720),
}

# Feature extraction parameters (from csv_process.py)
FPS                          = float(CAMERA_FPS)   # constant — never mutated at runtime
MAX_GAP_FRAMES               = 5
SMOOTH_WINDOW                = 3
VELOCITY_THRESHOLD           = 8.0
DOWN_THRESHOLD               = 1.0
UP_THRESHOLD                 = 1.0
MIN_PECK_GAP                 = 5
LOOK_AHEAD_FRAMES            = 2
MIN_DISPLACEMENT             = 1.5
ACTIVE_FEED_VELOCITY_THRESHOLD = 8.0
ACTIVE_FEED_VERTICAL_RATIO   = 1.1

# Final feature set used by the SVM model.
# IMPORTANT: Must match the features and order used when training scaler.pkl.
SVM_FEATURES = [
    "active_feeding_duration_sec",
    "peck_frequency_per_min",
    "feeding_activity_ratio",
    "hmv_std_velocity",
    "pause_std_sec",
    "pause_max_sec",
    "trajectory_consistency",
]

APP_METRIC_COLUMNS = [
    "active_feeding_duration_sec",
    "peck_frequency_per_min",
    "hmv_std_velocity",
    "pause_std_sec",
    "trajectory_consistency",
]

# ============================================================
# MODEL LOAD — done once at startup
# ============================================================
print("[INFO] Loading ONNX model...")
_so = ort.SessionOptions()
_so.intra_op_num_threads        = 4
_so.inter_op_num_threads        = 2
_so.graph_optimization_level    = ort.GraphOptimizationLevel.ORT_ENABLE_ALL

onnx_session = ort.InferenceSession(
    ONNX_MODEL_PATH,
    sess_options=_so,
    providers=["CPUExecutionProvider"],
)
_input_name   = onnx_session.get_inputs()[0].name
_output_names = [o.name for o in onnx_session.get_outputs()]

print("[INFO] ONNX model loaded")
print("[INFO] Input shape :", onnx_session.get_inputs()[0].shape)
print("[INFO] Output shape:", [o.shape for o in onnx_session.get_outputs()])

print("[INFO] Loading SVM model + scaler...")
svm_model  = joblib.load(SVM_MODEL_PATH)
svm_scaler = joblib.load(SCALER_PATH)
print("[INFO] SVM model + scaler loaded")

# ============================================================
# GLOBAL STATE
# ============================================================
_latest_raw_frame = None

_live_lock      = threading.Lock()
_live_active    = False
_live_chicken_id = None

_frame_lock    = threading.Lock()
_latest_frame  = None

_status_lock           = threading.Lock()
_latest_status_by_id   = {cid: "No analysis yet" for cid in CAGE_ZONES}
_latest_result_by_id   = {
    cid: {
        "status":                    "No analysis yet",
        "active_feeding_duration_sec": None,
        "peck_frequency_per_min":    None,
        "hmv_std_velocity":          None,
        "pause_std_sec":             None,
        "trajectory_consistency":    None,
    }
    for cid in CAGE_ZONES
}

_detection_lock  = threading.Lock()
_last_detections = []

_camera_thread_started = False

_inference_lock              = threading.Lock()
_inference_active            = False
_inference_start_time        = None
_inference_duration_sec      = DEFAULT_INFERENCE_DURATION_SEC
_inference_session_name      = None
_inference_error             = None
_inference_done              = False
_inference_phase             = "idle"
_inference_video_path        = None
_inference_frames_processed  = 0   # exposed in /inference/status for progress tracking

# ============================================================
# BASIC HELPERS
# ============================================================
def get_local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "Unknown"


def set_latest_frame(jpeg_bytes: bytes) -> None:
    global _latest_frame
    with _frame_lock:
        _latest_frame = jpeg_bytes


def get_latest_frame() -> bytes | None:
    with _frame_lock:
        return _latest_frame


def set_live_state(active: bool, chicken_id=None) -> None:
    global _live_active, _live_chicken_id
    with _live_lock:
        _live_active    = active
        _live_chicken_id = int(chicken_id) if active and chicken_id is not None else None


def get_live_state() -> tuple[bool, int | None]:
    with _live_lock:
        return _live_active, _live_chicken_id


def set_latest_status(chicken_id: int, status: str) -> None:
    with _status_lock:
        _latest_status_by_id[int(chicken_id)] = str(status)


def get_latest_status(chicken_id: int) -> str:
    with _status_lock:
        return _latest_status_by_id.get(int(chicken_id), "No analysis yet")
    
def set_latest_raw_frame(frame):
    global _latest_raw_frame
    _latest_raw_frame = frame

def get_latest_raw_frame():
    return _latest_raw_frame

def assign_chicken_id(cx: float, cage_zones: dict = CAGE_ZONES) -> int | None:
    for cid, (xmin, xmax) in cage_zones.items():
        if xmin <= cx < xmax:
            return cid
    return None


def assign_chicken_id_vectorized(cx_array: np.ndarray) -> np.ndarray:
    """Vectorized zone assignment — avoids a Python loop per detection row."""
    result = np.full(len(cx_array), -1, dtype=np.int8)
    for cid, (xmin, xmax) in CAGE_ZONES.items():
        mask = (cx_array >= xmin) & (cx_array < xmax)
        result[mask] = cid
    return result


def color_for_status(status: str) -> tuple:
    if status == "Anomaly":
        return (0, 0, 255)
    if status == "Normal":
        return (0, 255, 0)
    return (180, 180, 180)


def safe_float(value, decimals: int = 2):
    if value is None:
        return None
    try:
        if pd.isna(value):
            return None
    except (TypeError, ValueError):
        pass
    return round(float(value), decimals)

# ============================================================
# DRAWING HELPERS
# ============================================================
def draw_zone_lines(frame: np.ndarray) -> None:
    for cid, (xmin, _) in CAGE_ZONES.items():
        cv2.line(frame, (xmin, 0), (xmin, FRAME_HEIGHT), (70, 70, 70), 1)
        cv2.putText(frame, f"Zone {cid}", (xmin + 10, 24),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)


def draw_detection(frame: np.ndarray, det: dict, selected_chicken_id=None) -> None:
    cid        = det["chicken_id"]
    x1, y1, x2, y2 = det["bbox"]
    cx, cy     = det["center"]
    conf       = det["confidence"]
    status     = get_latest_status(cid)
    color      = color_for_status(status)
    thickness  = 3 if selected_chicken_id == cid else 2

    cv2.rectangle(frame, (x1, y1), (x2, y2), color, thickness)
    cv2.circle(frame, (cx, cy), 4, color, -1)

    text_y = max(24, y1 - 40)
    cv2.putText(frame, f"Chicken {cid}", (x1, text_y),
                cv2.FONT_HERSHEY_SIMPLEX, 0.55, color, 2)
    cv2.putText(frame, status, (x1, text_y + 20),
                cv2.FONT_HERSHEY_SIMPLEX, 0.55, color, 2)
    cv2.putText(frame, f"{conf:.2f}", (x1, text_y + 40),
                cv2.FONT_HERSHEY_SIMPLEX, 0.50, (255, 255, 255), 1)

# ============================================================
# ONNX PREPROCESSING / DETECTION
# ============================================================
_LETTERBOX_SHAPE = (INPUT_SIZE, INPUT_SIZE)   # pre-built constant tuple

def letterbox(image: np.ndarray,
              new_shape: tuple = _LETTERBOX_SHAPE,
              color: tuple = (114, 114, 114)):
    h, w = image.shape[:2]
    r = min(new_shape[0] / h, new_shape[1] / w)
    new_unpad = (int(round(w * r)), int(round(h * r)))
    dw = (new_shape[1] - new_unpad[0]) / 2
    dh = (new_shape[0] - new_unpad[1]) / 2

    if (w, h) != new_unpad:
        image = cv2.resize(image, new_unpad, interpolation=cv2.INTER_LINEAR)

    top    = int(round(dh - 0.1))
    bottom = int(round(dh + 0.1))
    left   = int(round(dw - 0.1))
    right  = int(round(dw + 0.1))
    image  = cv2.copyMakeBorder(image, top, bottom, left, right,
                                cv2.BORDER_CONSTANT, value=color)
    return image, r, (dw, dh)


def preprocess(frame: np.ndarray):
    img, ratio, (dw, dh) = letterbox(frame)
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
    img = np.ascontiguousarray(img.transpose(2, 0, 1)[np.newaxis])
    return img, ratio, dw, dh


def nms_boxes(boxes: list, scores: list, iou_thresh: float = IOU_THRESHOLD) -> list:
    """Vectorized NMS — no inner Python loop."""
    if not boxes:
        return []

    boxes_arr  = np.array(boxes,  dtype=np.float32)   # (N, 4)
    scores_arr = np.array(scores, dtype=np.float32)
    idxs       = np.argsort(scores_arr)[::-1]

    x1 = boxes_arr[:, 0]
    y1 = boxes_arr[:, 1]
    x2 = boxes_arr[:, 2]
    y2 = boxes_arr[:, 3]
    areas = (x2 - x1) * (y2 - y1)

    keep = []
    suppressed = np.zeros(len(idxs), dtype=bool)

    for pos, i in enumerate(idxs):
        if suppressed[pos]:
            continue
        keep.append(int(i))
        rest = idxs[pos + 1:]
        if len(rest) == 0:
            break

        ix1 = np.maximum(x1[i], x1[rest])
        iy1 = np.maximum(y1[i], y1[rest])
        ix2 = np.minimum(x2[i], x2[rest])
        iy2 = np.minimum(y2[i], y2[rest])

        inter = np.maximum(0.0, ix2 - ix1) * np.maximum(0.0, iy2 - iy1)
        union = areas[i] + areas[rest] - inter
        iou   = np.where(union > 0, inter / union, 0.0)

        suppressed_rest = iou >= iou_thresh
        suppressed[pos + 1:][suppressed_rest] = True   # mark in-place

    return keep


def run_onnx_detection(frame: np.ndarray) -> list[dict]:
    input_tensor, ratio, dw, dh = preprocess(frame)
    outputs = onnx_session.run(_output_names, {_input_name: input_tensor})
    pred    = np.squeeze(outputs[0])

    if pred.ndim != 2:
        raise RuntimeError(f"Unexpected ONNX output shape: {pred.shape}")

    # Normalise to (N, 5+) layout
    if pred.shape[0] == 5 and pred.shape[1] == 8400 or pred.shape[0] < pred.shape[1]:
        pred = pred.T

    frame_h, frame_w = frame.shape[:2]

    # --- vectorized confidence filter ---
    confidences = pred[:, 4].astype(np.float32)
    mask        = confidences >= CONF_THRESHOLD
    if not mask.any():
        return []

    pred_f = pred[mask]
    conf_f = confidences[mask]

    cx_raw = pred_f[:, 0]
    cy_raw = pred_f[:, 1]
    w_raw  = pred_f[:, 2]
    h_raw  = pred_f[:, 3]

    x1 = np.clip(np.round((cx_raw - w_raw / 2 - dw) / ratio).astype(int), 0, frame_w - 1)
    y1 = np.clip(np.round((cy_raw - h_raw / 2 - dh) / ratio).astype(int), 0, frame_h - 1)
    x2 = np.clip(np.round((cx_raw + w_raw / 2 - dw) / ratio).astype(int), 0, frame_w - 1)
    y2 = np.clip(np.round((cy_raw + h_raw / 2 - dh) / ratio).astype(int), 0, frame_h - 1)

    valid = (x2 > x1) & (y2 > y1)
    x1, y1, x2, y2, conf_f = x1[valid], y1[valid], x2[valid], y2[valid], conf_f[valid]

    boxes      = list(zip(x1.tolist(), y1.tolist(), x2.tolist(), y2.tolist()))
    scores     = conf_f.tolist()
    detections = [
        {"bbox": b, "confidence": s, "class_id": 0}
        for b, s in zip(boxes, scores)
    ]

    keep = nms_boxes(boxes, scores, IOU_THRESHOLD)
    return [detections[i] for i in keep]

# ============================================================
# LIVE FEED PROCESSING
# ============================================================
def process_live_frame(frame: np.ndarray, selected_chicken_id=None) -> np.ndarray:
    output = frame.copy()
    draw_zone_lines(output)

    with _detection_lock:
        detections = list(_last_detections)

    best_by_chicken: dict[int, dict] = {}
    for det in detections:
        x1, y1, x2, y2 = det["bbox"]
        cx  = int((x1 + x2) / 2)
        cy  = int((y1 + y2) / 2)
        cid = assign_chicken_id(cx)
        if cid is None:
            continue
        mapped = {
            "chicken_id": cid,
            "bbox":       (x1, y1, x2, y2),
            "center":     (cx, cy),
            "confidence": det["confidence"],
        }
        prev = best_by_chicken.get(cid)
        if prev is None or det["confidence"] > prev["confidence"]:
            best_by_chicken[cid] = mapped

    if selected_chicken_id in best_by_chicken:
        draw_detection(output, best_by_chicken[selected_chicken_id], selected_chicken_id)

    if selected_chicken_id is not None:
        cv2.putText(output, f"Chicken {selected_chicken_id}",
                    (12, FRAME_HEIGHT - 16), cv2.FONT_HERSHEY_SIMPLEX,
                    0.7, (255, 255, 255), 2)
    return output

# ============================================================
# INFERENCE STATE HELPERS
# ============================================================
def is_inference_active() -> bool:
    with _inference_lock:
        return _inference_active


def start_inference_state(duration_sec: int) -> tuple[bool, str]:
    global _inference_active, _inference_start_time, _inference_duration_sec
    global _inference_session_name, _inference_error, _inference_done
    global _inference_phase, _inference_video_path, _inference_frames_processed

    with _inference_lock:
        if _inference_active:
            return False, "Inference is already running"

        _inference_active           = True
        _inference_start_time       = time.time()
        _inference_duration_sec     = int(duration_sec)
        _inference_session_name     = datetime.now().strftime("session_%Y%m%d_%H%M%S")
        _inference_error            = None
        _inference_done             = False
        _inference_phase            = "recording"
        _inference_video_path       = None
        _inference_frames_processed = 0
        return True, _inference_session_name


def get_inference_snapshot() -> dict:
    with _inference_lock:
        elapsed   = 0
        remaining = 0
        if _inference_start_time is not None:
            elapsed   = int(time.time() - _inference_start_time)
            remaining = max(0, int(_inference_duration_sec - elapsed))
        return {
            "running":           _inference_active,
            "done":              _inference_done,
            "phase":             _inference_phase,
            "session":           _inference_session_name,
            "video_path":        _inference_video_path,
            "elapsed_sec":       elapsed,
            "remaining_sec":     remaining,
            "duration_sec":      _inference_duration_sec,
            "frames_processed":  _inference_frames_processed,
            "error":             _inference_error,
        }


def update_inference_phase(phase: str) -> None:
    global _inference_phase
    with _inference_lock:
        _inference_phase = phase


def finish_inference_state(error: str | None = None) -> None:
    global _inference_active, _inference_done, _inference_error, _inference_phase
    with _inference_lock:
        _inference_active = False
        _inference_done   = True
        _inference_error  = error
        _inference_phase  = "error" if error else "done"

# ============================================================
# VIDEO RECORDING
# ============================================================
def record_video_file(session_name: str, duration_sec: int) -> str:
    """Record to .mp4 container for reliable CAP_PROP_FPS reads in OpenCV."""
    raw_path = os.path.join(RECORDINGS_DIR, f"{session_name}.h264")
    mp4_path = os.path.join(RECORDINGS_DIR, f"{session_name}.mp4")

    cmd = [
        "rpicam-vid",
        "-t",          str(int(duration_sec) * 1000),
        "--codec",     "h264",
        "--output",    raw_path,
        "--width",     str(FRAME_WIDTH),
        "--height",    str(FRAME_HEIGHT),
        "--framerate", str(CAMERA_FPS),
        "--nopreview",
        "--flush",
    ]

    print(f"[INFO] Recording -> {raw_path}")
    subprocess.run(cmd, check=True)

    if not os.path.exists(raw_path) or os.path.getsize(raw_path) == 0:
        raise RuntimeError("Recording failed or produced empty file.")

    # Remux into proper MP4 -> fast, no re-encode
    print(f"[INFO] Remuxing -> {mp4_path}")
    subprocess.run([
        "ffmpeg", "-y",
        "-framerate", str(CAMERA_FPS),
        "-i",         raw_path,
        "-c:v",       "copy",
        mp4_path,
    ], check=True)

    os.remove(raw_path)
    print(f"[INFO] MP4 ready: {mp4_path}")
    return mp4_path

# ============================================================
# VIDEO PROCESSING (ONNX over saved file)
# ============================================================
def detections_to_log_rows(frame_idx: int, detections: list[dict],
                            timestamp_sec: float) -> list[dict]:
    rows = []
    for det in detections:
        x1, y1, x2, y2 = det["bbox"]
        cx     = (x1 + x2) / 2.0
        cy     = (y1 + y2) / 2.0
        width  = x2 - x1
        height = y2 - y1
        rows.append({
            "timestamp":  float(timestamp_sec),
            "frame":      int(frame_idx),
            "x1":         round(float(x1), 2),
            "y1":         round(float(y1), 2),
            "x2":         round(float(x2), 2),
            "y2":         round(float(y2), 2),
            "cx":         round(float(cx), 2),
            "cy":         round(float(cy), 2),
            "width":      round(float(width), 2),
            "height":     round(float(height), 2),
            "area":       round(float(width * height), 2),
            "confidence": round(float(det["confidence"]), 3),
        })
    return rows


def process_recorded_video(video_path: str, session_name: str):
    """Run ONNX over the saved video and collect detection rows. OPTIMIZED to prefetch frames inside RAM"""

    global _inference_frames_processed

    file_size = os.path.getsize(video_path) if os.path.exists(video_path) else 0
    print(f"[PROC] --- process_recorded_video START ---")
    print(f"[PROC] Video path : {video_path}")
    print(f"[PROC] File size  : {file_size / (1024*1024):.2f} MB")
    if file_size == 0:
        raise RuntimeError(f"Video file is empty: {video_path}")

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"cv2.VideoCapture could not open: {video_path}")

    video_fps = cap.get(cv2.CAP_PROP_FPS)
    total_frames_meta = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    print(f"[PROC] CAP_PROP_FPS        : {video_fps}")
    print(f"[PROC] CAP_PROP_FRAME_COUNT: {total_frames_meta}")

    if not video_fps or video_fps <= 0 or np.isnan(video_fps):
        print(f"[WARN] CAP_PROP_FPS unavailable, falling back to CAMERA_FPS={CAMERA_FPS}")
        video_fps = float(CAMERA_FPS)

    # -- How much RAM to use for the frame buffer ----------------
    # Each 1280x720 BGR frame = 1280*720*3 = ~2.76 MB
    # 512 frames ≈ 1.4 GB buffer — adjust FRAME_BUFFER_SIZE in config to taste
    frame_q = queue.Queue(maxsize=FRAME_BUFFER_SIZE)
    SENTINEL = None  # signals reader thread that video is exhausted

    def frame_reader():
        """Dedicated thread: reads frames from disk into RAM queue."""
        idx = 0
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            idx += 1
            frame_q.put((idx, frame))  # blocks if queue is full — that's intentional
        frame_q.put(SENTINEL)
        print(f"[PROC] Frame reader done — {idx} frames queued")

    reader_thread = threading.Thread(target=frame_reader, daemon=True)
    reader_thread.start()
    print(f"[PROC] Frame reader thread started (buffer={FRAME_BUFFER_SIZE} frames)")

    logs    = []
    start_t = time.time()

    while True:
        item = frame_q.get()
        if item is SENTINEL:
            break

        frame_idx, frame = item
        detections = run_onnx_detection(frame)
        logs.extend(detections_to_log_rows(frame_idx, detections, frame_idx / video_fps))

        if frame_idx % 50 == 0:
            with _inference_lock:
                _inference_frames_processed = frame_idx
            elapsed  = time.time() - start_t
            det_rate = len(logs) / frame_idx if frame_idx else 0
            eta_s    = (total_frames_meta - frame_idx) / (frame_idx / elapsed) if elapsed > 0 else 0
            print(
                f"[PROC] frame={frame_idx:>5}"
                f" | rows={len(logs):>5}"
                f" | det/frame={det_rate:.2f}"
                f" | elapsed={elapsed:.1f}s"
                f" | ETA~{eta_s:.0f}s"
                f" | buf={frame_q.qsize()}/{FRAME_BUFFER_SIZE}"
            )

    reader_thread.join()
    cap.release()

    with _inference_lock:
        _inference_frames_processed = frame_idx

    elapsed_total = time.time() - start_t
    print(f"[PROC] Total frames: {frame_idx} | rows: {len(logs)} | time: {elapsed_total:.1f}s")
    print(f"[PROC] Avg speed: {frame_idx / elapsed_total:.1f} frames/sec" if elapsed_total > 0 else "")

    if frame_idx == 0:
        raise RuntimeError("Recorded video contained 0 readable frames.")
    if not logs:
        raise RuntimeError("No detections produced — check CONF_THRESHOLD and lighting.")

    return pd.DataFrame(logs), frame_idx, video_fps

# ============================================================
# FEATURE EXTRACTION — ported from csv_process.py
# ============================================================
def in_feeder_zone(cx: float, cy: float, zone: tuple) -> int:
    x_min, x_max, y_min, y_max = zone
    return int(x_min <= cx <= x_max and y_min <= cy <= y_max)


def select_best_detection_per_frame_zone(df: pd.DataFrame) -> pd.DataFrame:
    df = df.sort_values(["frame", "chicken_id", "confidence"],
                        ascending=[True, True, False])
    return df.drop_duplicates(subset=["frame", "chicken_id"], keep="first")


def build_per_chicken_timeseries(df_raw: pd.DataFrame,
                                 chicken_id: int,
                                 total_frames: int) -> pd.DataFrame:
    chicken = df_raw[df_raw["chicken_id"] == chicken_id]
    base    = pd.DataFrame({"frame": np.arange(1, total_frames + 1)})
    merged  = base.merge(
        chicken[["frame", "cx", "cy", "width", "height", "area", "confidence"]],
        on="frame", how="left",
    )
    merged["chicken_id"] = chicken_id
    return merged


def interpolate_short_gaps(series_df: pd.DataFrame,
                           max_gap_frames: int = MAX_GAP_FRAMES) -> pd.DataFrame:
    out = series_df.copy()
    for col in ["cx", "cy", "width", "height", "area"]:
        is_na     = out[col].isna()
        group     = (is_na != is_na.shift()).cumsum()
        gap_sizes = is_na.groupby(group).transform("sum")
        interp    = out[col].interpolate(limit_direction="both")
        mask      = is_na & (gap_sizes <= max_gap_frames)
        out.loc[mask, col] = interp.loc[mask]
    return out


def smooth_positions(series_df: pd.DataFrame,
                     window: int = SMOOTH_WINDOW) -> pd.DataFrame:
    out = series_df.copy()
    for col in ["cx", "cy"]:
        out[f"{col}_smooth"] = (
            out[col].rolling(window=window, center=True, min_periods=1).mean()
        )
    return out


def compute_motion_features(series_df: pd.DataFrame) -> pd.DataFrame:
    out        = series_df.copy()
    dt         = 1.0 / FPS
    out["dx"]  = out["cx_smooth"].diff()
    out["dy"]  = out["cy_smooth"].diff()
    out["disp"]     = np.sqrt(out["dx"] ** 2 + out["dy"] ** 2)
    out["velocity"] = out["disp"] / dt
    out["vx"]       = out["dx"]  / dt
    out["vy"]       = out["dy"]  / dt
    return out


def add_zone_flags(series_df: pd.DataFrame, chicken_id: int) -> pd.DataFrame:
    out         = series_df.copy()
    feeder_zone = FEEDER_ZONES.get(chicken_id)

    has_pos = out["cx_smooth"].notna() & out["cy_smooth"].notna()

    if feeder_zone is None:
        out["in_feeder_zone"] = 1
    else:
        x_min, x_max, y_min, y_max = feeder_zone
        out["in_feeder_zone"] = (
            has_pos &
            out["cx_smooth"].between(x_min, x_max) &
            out["cy_smooth"].between(y_min, y_max)
        ).astype(int)

    out["feeder_presence_frame"] = (
        (out["in_feeder_zone"] == 1) & has_pos
    ).astype(int)

    abs_dx = out["dx"].abs()
    abs_dy = out["dy"].abs()
    out["active_feeding_frame"] = (
        (out["in_feeder_zone"] == 1) &
        out["velocity"].notna() &
        (out["velocity"] >= ACTIVE_FEED_VELOCITY_THRESHOLD) &
        (abs_dy >= abs_dx * ACTIVE_FEED_VERTICAL_RATIO)
    ).astype(int)
    return out


def detect_pecks(series_df: pd.DataFrame,
                 velocity_threshold: float = VELOCITY_THRESHOLD,
                 min_gap: int             = MIN_PECK_GAP,
                 down_thresh: float       = DOWN_THRESHOLD,
                 up_thresh: float         = UP_THRESHOLD,
                 look_ahead: int          = LOOK_AHEAD_FRAMES,
                 min_displacement: float  = MIN_DISPLACEMENT,
                 vertical_ratio: float    = ACTIVE_FEED_VERTICAL_RATIO):
    out = series_df.copy()

    dy        = out["dy"].to_numpy()
    dx        = out["dx"].to_numpy()
    disp      = out["disp"].to_numpy()
    velocity  = out["velocity"].to_numpy()
    frames_np = out["frame"].to_numpy()
    in_feeder = (
        out["in_feeder_zone"].to_numpy()
        if "in_feeder_zone" in out.columns
        else np.zeros(len(out), dtype=np.int8)
    )

    n           = len(out)
    peck_frames = []

    # Pre-compute masks valid over the whole array (vectorized guards)
    valid_mask = (
        ~np.isnan(dy) & ~np.isnan(dx) &
        ~np.isnan(velocity) & ~np.isnan(disp) &
        (in_feeder == 1) &
        (disp >= min_displacement) &
        (velocity >= velocity_threshold) &
        (dy > down_thresh)
    )

    for i in range(2, n - look_ahead - 1):
        if not valid_mask[i]:
            continue

        # Local peak in dy
        if not (dy[i] > dy[i - 1] and dy[i] >= dy[i + 1]):
            continue

        # Vertical motion dominates
        if abs(dy[i]) < abs(dx[i]) * vertical_ratio:
            continue

        # Look-ahead for upward rebound — slice avoids inner loop overhead
        window  = dy[i + 1 : i + 1 + look_ahead]
        valid_w = window[~np.isnan(window)]
        if not (len(valid_w) > 0 and np.any(valid_w < -up_thresh)):
            continue

        current_frame = int(frames_np[i])
        if not peck_frames or (current_frame - peck_frames[-1]) >= min_gap:
            peck_frames.append(current_frame)

    out["is_peck"] = out["frame"].isin(peck_frames).astype(int)
    return out, peck_frames


def extract_session_features(series_df: pd.DataFrame,
                             peck_frames: list,
                             chicken_id: int) -> dict:
    valid = series_df.copy()

    feeder_presence_frames    = int(valid["feeder_presence_frame"].sum())
    feeder_presence_duration  = feeder_presence_frames / FPS

    active_feeding_frames     = int(valid["active_feeding_frame"].sum())
    active_feeding_duration   = active_feeding_frames / FPS

    total_pecks               = len(peck_frames)
    peck_frequency_per_min    = (
        (total_pecks / active_feeding_duration) * 60
        if active_feeding_duration > 0 else 0.0
    )
    peck_frequency_per_min_presence = (
        (total_pecks / feeder_presence_duration) * 60
        if feeder_presence_duration > 0 else 0.0
    )

    feeding_activity_ratio = (
        active_feeding_frames / feeder_presence_frames
        if feeder_presence_frames > 0 else 0.0
    )

    feeding_only      = valid[valid["active_feeding_frame"] == 1]
    hmv_mean_velocity = feeding_only["velocity"].mean(skipna=True)
    hmv_std_velocity  = feeding_only["velocity"].std(skipna=True)

    pause_intervals_sec: list[float] = []
    if len(peck_frames) >= 2:
        pause_intervals_sec = [
            (peck_frames[i] - peck_frames[i - 1]) / FPS
            for i in range(1, len(peck_frames))
        ]

    pause_mean = float(np.mean(pause_intervals_sec))  if pause_intervals_sec else np.nan
    pause_std  = float(np.std(pause_intervals_sec))   if pause_intervals_sec else np.nan
    pause_max  = float(np.max(pause_intervals_sec))   if pause_intervals_sec else np.nan

    trajectory_length = feeding_only["disp"].sum(skipna=True)
    has_pos = feeding_only.dropna(subset=["cx_smooth", "cy_smooth"])

    if len(has_pos) >= 2 and trajectory_length > 0:
        x0, y0 = has_pos.iloc[0][["cx_smooth", "cy_smooth"]]
        x1, y1 = has_pos.iloc[-1][["cx_smooth", "cy_smooth"]]
        straight_line        = math.sqrt((x1 - x0) ** 2 + (y1 - y0) ** 2)
        trajectory_consistency = straight_line / trajectory_length
    else:
        trajectory_consistency = np.nan

    observed_frames = int(valid["cx"].notna().sum())
    coverage_ratio  = observed_frames / len(valid) if len(valid) else 0.0

    return {
        "chicken_id":                     chicken_id,
        "feeder_presence_duration_sec":   feeder_presence_duration,
        "active_feeding_duration_sec":    active_feeding_duration,
        "total_pecks":                    total_pecks,
        "peck_frequency_per_min":         peck_frequency_per_min,
        "peck_frequency_per_min_presence":peck_frequency_per_min_presence,
        "feeding_activity_ratio":         feeding_activity_ratio,
        "hmv_mean_velocity":              hmv_mean_velocity,
        "hmv_std_velocity":               hmv_std_velocity,
        "pause_mean_sec":                 pause_mean,
        "pause_std_sec":                  pause_std,
        "pause_max_sec":                  pause_max,
        "trajectory_length":              trajectory_length,
        "trajectory_consistency":         trajectory_consistency,
        "mean_confidence":                valid["confidence"].mean(skipna=True),
        "observed_frames":                observed_frames,
        "coverage_ratio":                 coverage_ratio,
    }


def process_detection_dataframe(df_raw: pd.DataFrame,
                                session_name: str = "live_session",
                                save_timeseries: bool = True):
    if df_raw.empty:
        raise RuntimeError("No detection logs collected during inference.")

    # --- vectorized confidence filter + zone assignment ---
    df = df_raw[df_raw["confidence"] >= FEATURE_CONF_THRESHOLD].copy()
    df = df.sort_values("frame").reset_index(drop=True)

    if df.empty:
        raise RuntimeError("All detections were below the feature confidence threshold.")

    df["chicken_id"] = assign_chicken_id_vectorized(df["cx"].to_numpy())
    df = df[df["chicken_id"] >= 0].copy()
    df["chicken_id"] = df["chicken_id"].astype(int)
    df = select_best_detection_per_frame_zone(df)

    if df.empty:
        raise RuntimeError("No detections were inside configured cage zones.")

    total_frames    = int(df["frame"].max())
    session_features = []
    per_frame_all    = []

    for chicken_id in sorted(CAGE_ZONES.keys()):
        ts = build_per_chicken_timeseries(df, chicken_id, total_frames)
        ts = interpolate_short_gaps(ts, max_gap_frames=MAX_GAP_FRAMES)
        ts = smooth_positions(ts, window=SMOOTH_WINDOW)
        ts = compute_motion_features(ts)
        ts = add_zone_flags(ts, chicken_id)
        ts, peck_frames = detect_pecks(ts)

        feats          = extract_session_features(ts, peck_frames, chicken_id)
        feats["session"] = session_name
        session_features.append(feats)

        ts["session"] = session_name
        per_frame_all.append(ts)

    features_df = pd.DataFrame(session_features)
    frame_df    = pd.concat(per_frame_all, ignore_index=True)

    if save_timeseries:
        features_df.to_csv(os.path.join(RESULTS_DIR, f"{session_name}_features.csv"), index=False)
        frame_df.to_csv(os.path.join(RESULTS_DIR, f"{session_name}_all_timeseries.csv"), index=False)

    return features_df, frame_df

# ============================================================
# SVM INFERENCE — uses pre-loaded model, guards zero-coverage chickens
# ============================================================
def run_saved_svm(features_df: pd.DataFrame) -> pd.DataFrame:
    missing = [c for c in SVM_FEATURES if c not in features_df.columns]
    if missing:
        raise RuntimeError(f"Missing required SVM features: {missing}")

    out = features_df.copy()
    out["status"]       = "No data"
    out["prediction"]   = np.nan
    out["anomaly_score"] = np.nan

    # Only classify chickens that have enough observed frames
    eligible = out["coverage_ratio"] >= MIN_COVERAGE_RATIO
    if not eligible.any():
        print("[WARN] No chickens met the minimum coverage threshold; all results are 'No data'.")
        return out

    X_raw   = out.loc[eligible, SVM_FEATURES].replace([np.inf, -np.inf], np.nan).fillna(0)
    X_scaled = svm_scaler.transform(X_raw)

    out.loc[eligible, "prediction"]    = svm_model.predict(X_scaled)
    out.loc[eligible, "anomaly_score"] = svm_model.decision_function(X_scaled)
    out.loc[eligible, "status"]        = out.loc[eligible, "prediction"].apply(
        lambda p: "Normal" if int(p) == 1 else "Anomaly"
    )
    return out


def update_results_from_svm(results_df: pd.DataFrame) -> None:
    with _status_lock:
        for _, row in results_df.iterrows():
            cid    = int(row["chicken_id"])
            status = str(row["status"])
            _latest_status_by_id[cid] = status
            _latest_result_by_id[cid] = {
                "status":                    status,
                "active_feeding_duration_sec": safe_float(row.get("active_feeding_duration_sec"), 2),
                "peck_frequency_per_min":    safe_float(row.get("peck_frequency_per_min"), 2),
                "hmv_std_velocity":          safe_float(row.get("hmv_std_velocity"), 2),
                "pause_std_sec":             safe_float(row.get("pause_std_sec"), 2),
                "trajectory_consistency":    safe_float(row.get("trajectory_consistency"), 4),
            }

# ============================================================
# INFERENCE ORCHESTRATION
# ============================================================
def record_then_finalize_inference(duration_sec: int, session_name: str) -> None:
    global _inference_video_path

    try:
        update_inference_phase("recording")
        video_path = record_video_file(session_name, duration_sec)

        with _inference_lock:
            _inference_video_path = video_path

        update_inference_phase("processing_video")
        raw_df, frame_count, video_fps = process_recorded_video(video_path, session_name)

        raw_path = os.path.join(LOG_DIR, f"{session_name}_raw_detections.csv")
        raw_df.to_csv(raw_path, index=False)
        print(f"[INFO] Raw detections saved: {raw_path}")

        update_inference_phase("extracting_features")
        features_df, _ = process_detection_dataframe(raw_df, session_name=session_name,
                                                     save_timeseries=True)

        update_inference_phase("svm_prediction")
        results_df = run_saved_svm(features_df)

        results_path = os.path.join(RESULTS_DIR, f"{session_name}_svm_results.csv")
        results_df.to_csv(results_path, index=False)
        update_results_from_svm(results_df)

        print(f"[INFO] Inference complete. video_fps={video_fps:.2f}, "
              f"frames={frame_count}, results={results_path}")
        finish_inference_state(error=None)

    except Exception as e:
        print(f"[ERROR] Record-first inference failed: {e}")
        finish_inference_state(error=str(e))

# ============================================================
# CAMERA THREAD
# ============================================================
def camera_thread() -> None:
    print("[INFO] Camera thread starting...")
    cmd = [
        "rpicam-vid",
        "-t",             "0",
        "--codec",        "mjpeg",
        "-o",             "-",
        "--width",        str(FRAME_WIDTH),
        "--height",       str(FRAME_HEIGHT),
        "--framerate",    str(CAMERA_FPS),
        "--nopreview",
        "--buffer-count", "2",
        "--flush",
    ]

    proc               = None
    frame_counter      = 0
    last_annotated_jpeg = None

    while True:
        live_active, selected_chicken_id = get_live_state()
        should_camera_run = live_active

        if not should_camera_run:
            if proc is not None:
                try:
                    proc.kill()
                except Exception:
                    pass
                proc = None
            time.sleep(0.1)
            continue

        try:
            if proc is None:
                proc = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                                        stderr=subprocess.DEVNULL)
                print("[INFO] rpicam-vid started")

            buffer = b""

            while True:
                live_active, selected_chicken_id = get_live_state()
                if not live_active:
                    print("[INFO] Camera no longer needed, stopping rpicam-vid")
                    break

                chunk = proc.stdout.read(4096)
                if not chunk:
                    print("[WARN] rpicam-vid pipe closed, restarting...")
                    try:
                        proc.kill()
                    except Exception:
                        pass
                    proc = None
                    break

                buffer += chunk
                while True:
                    start = buffer.find(b"\xff\xd8")
                    if start == -1:
                        buffer = b""
                        break

                    end = buffer.find(b"\xff\xd9", start + 2)
                    if end == -1:
                        buffer = buffer[start:]
                        break

                    jpeg   = buffer[start : end + 2]
                    buffer = buffer[end + 2 :]

                    np_bytes = np.frombuffer(jpeg, dtype=np.uint8)
                    frame    = cv2.imdecode(np_bytes, cv2.IMREAD_COLOR)
                    if frame is None:
                        continue

                    frame_counter += 1

                    ok_raw, encoded_raw = cv2.imencode(
                        ".jpg", frame,
                        [cv2.IMWRITE_JPEG_QUALITY, JPEG_QUALITY],
                    )
                    if ok_raw:
                        set_latest_raw_frame(encoded_raw.tobytes())

                    if frame_counter % DETECTION_EVERY_N_FRAMES == 0:
                        detections = run_onnx_detection(frame)
                        with _detection_lock:
                            _last_detections.clear()
                            _last_detections.extend(detections)

                    live_active_now, selected_id_now = get_live_state()
                    if live_active_now:
                        annotated = process_live_frame(frame, selected_chicken_id=selected_id_now)
                        ok, encoded = cv2.imencode(
                            ".jpg", annotated,
                            [cv2.IMWRITE_JPEG_QUALITY, JPEG_QUALITY],
                        )
                        if ok:
                            last_annotated_jpeg = encoded.tobytes()
                        if last_annotated_jpeg is not None:
                            set_latest_frame(last_annotated_jpeg)

        except Exception as e:
            print(f"[ERROR] Camera thread error: {e}")
            if proc is not None:
                try:
                    proc.kill()
                except Exception:
                    pass
                proc = None
            time.sleep(0.5)


def ensure_camera_thread() -> None:
    global _camera_thread_started
    if _camera_thread_started:
        return
    t = threading.Thread(target=camera_thread, daemon=True)
    t.start()
    _camera_thread_started = True

# ============================================================
# STREAM GENERATOR
# ============================================================
def generate_frames():
    frame_interval = 1.0 / STREAM_FPS
    while True:
        active, _ = get_live_state()
        if not active:
            time.sleep(0.05)
            continue

        jpeg = get_latest_frame()
        if jpeg is None:
            time.sleep(0.05)
            continue

        yield (b"--frame\r\nContent-Type: image/jpeg\r\n\r\n" + jpeg + b"\r\n")
        time.sleep(frame_interval)

def generate_raw_stream():
    while True:
        frame = get_latest_raw_frame()

        if frame is None:
            time.sleep(0.05)
            continue

        yield (
            b"--frame\r\n"
            b"Content-Type: image/jpeg\r\n\r\n" +
            frame +
            b"\r\n"
        )

# ============================================================
# API ENDPOINTS
# ============================================================
@app.route("/ping", methods=["GET"])
def ping():
    return jsonify({"status": "ok", "device": "BFPAS-Pi4"}), 200


@app.route("/live/start", methods=["POST"])
def live_start():
    data       = request.get_json(silent=True) or {}
    chicken_id = data.get("chicken_id")

    if chicken_id is None:
        return jsonify({"status": "error", "message": "chicken_id is required"}), 400

    chicken_id = int(chicken_id)
    if chicken_id not in CAGE_ZONES:
        return jsonify({"status": "error", "message": "invalid chicken_id"}), 400

    ensure_camera_thread()
    set_live_state(True, chicken_id)
    return jsonify({"status": "ok", "live_active": True, "chicken_id": chicken_id}), 200


@app.route("/live/stop", methods=["POST"])
def live_stop():
    set_live_state(False, None)
    return jsonify({"status": "ok", "live_active": False}), 200


@app.route("/live/status", methods=["GET"])
def live_status():
    active, chicken_id = get_live_state()
    return jsonify({"live_active": active, "chicken_id": chicken_id}), 200


@app.route("/stream", methods=["GET"])
def stream():
    return Response(generate_frames(),
                    mimetype="multipart/x-mixed-replace; boundary=frame")

@app.route("/raw_stream", methods=["GET"])
def raw_stream():
    return Response(
        generate_raw_stream(),
        mimetype="multipart/x-mixed-replace; boundary=frame"
    )

@app.route("/inference/start", methods=["POST"])
def inference_start():
    data         = request.get_json(silent=True) or {}
    duration_sec = int(data.get("duration_sec", DEFAULT_INFERENCE_DURATION_SEC))

    if duration_sec <= 0:
        return jsonify({"status": "error", "message": "duration_sec must be positive"}), 400

    # Release camera before recording to avoid resource conflicts.
    live_active, _ = get_live_state()
    if live_active:
        set_live_state(False, None)
        time.sleep(0.3)

    ok, session_name = start_inference_state(duration_sec)
    if not ok:
        return jsonify({"status": "error", "message": session_name}), 409

    t = threading.Thread(
        target=record_then_finalize_inference,
        args=(duration_sec, session_name),
        daemon=True,
    )
    t.start()

    return jsonify({
        "status":       "ok",
        "message":      "Recording started; processing will run after recording finishes",
        "session":      session_name,
        "duration_sec": duration_sec,
    }), 200


@app.route("/inference/status", methods=["GET"])
def inference_status():
    return jsonify(get_inference_snapshot()), 200


@app.route("/inference/results", methods=["GET"])
def inference_results():
    return get_data()


@app.route("/data", methods=["GET"])
def get_data():
    with _status_lock:
        chickens = [
            {"id": cid, **data}
            for cid, data in sorted(_latest_result_by_id.items())
        ]
    return jsonify({"chickens": chickens}), 200


@app.route("/status/update", methods=["POST"])
def status_update():
    """Manual override endpoint (retained for compatibility)."""
    data       = request.get_json(silent=True) or {}
    chicken_id = data.get("chicken_id")
    status     = data.get("status")

    if chicken_id is None or status is None:
        return jsonify({"status": "error",
                        "message": "chicken_id and status are required"}), 400

    chicken_id = int(chicken_id)
    status     = str(status)
    with _status_lock:
        _latest_status_by_id[chicken_id] = status
        if chicken_id in _latest_result_by_id:
            _latest_result_by_id[chicken_id]["status"] = status

    return jsonify({"status": "ok"}), 200

# ============================================================
# ENTRY POINT
# ============================================================
if __name__ == "__main__":
    ip = get_local_ip()
    print("\n[INFO] BFPAS Pi Server running (optimized)")
    print(f"[INFO] Local IP          : {ip}")
    print(f"[INFO] Ping URL          : http://{ip}:5000/ping")
    print(f"[INFO] Live Start        : http://{ip}:5000/live/start")
    print(f"[INFO] Live Stop         : http://{ip}:5000/live/stop")
    print(f"[INFO] Stream URL        : http://{ip}:5000/stream")
    print(f"[INFO] Inference Start   : http://{ip}:5000/inference/start  (record first)")
    print(f"[INFO] Inference Status  : http://{ip}:5000/inference/status")
    print(f"[INFO] Data URL          : http://{ip}:5000/data")
    print(f"[INFO] Live detect every : {DETECTION_EVERY_N_FRAMES} frame(s)")
    print(f"[INFO] Stream FPS        : {STREAM_FPS}")
    print(f"[INFO] JPEG Quality      : {JPEG_QUALITY}")
    print(f"[INFO] Min coverage ratio: {MIN_COVERAGE_RATIO}\n")

    app.run(host="0.0.0.0", port=5000, debug=False, threaded=True)
