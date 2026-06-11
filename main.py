import base64
import io
import json
import os
import re
import tempfile
from typing import List, Tuple

import cv2
import numpy as np
import requests
import torch
import uvicorn

from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from PIL import Image, ImageDraw, ImageFilter

app = FastAPI(title="GCV-AI Backend: Roboflow + SAM + Vehicle Customisation")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SAM_CHECKPOINT = "models/sam/sam_vit_b_01ec64.pth"
SAM_MODEL_TYPE = "vit_b"
FORGE_IMG2IMG_URL = "http://127.0.0.1:7861/sdapi/v1/img2img"
DEVICE = "mps" if torch.backends.mps.is_available() else "cpu"

sam_predictor = None

rembg_session = None

def load_rembg_session():

    global rembg_session

    if rembg_session is not None:

        return rembg_session

    print("Loading REMBG session...")

    from rembg import new_session

    rembg_session = new_session("u2netp")

    print("REMBG session loaded")

    return rembg_session

def load_sam():
    global sam_predictor

    if sam_predictor is not None:
        return sam_predictor

    print("Loading SAM...")

    from segment_anything import sam_model_registry, SamPredictor

    sam = sam_model_registry[SAM_MODEL_TYPE](checkpoint=SAM_CHECKPOINT)
    sam.to(device=DEVICE)
    sam.eval()

    sam_predictor = SamPredictor(sam)

    print(f"SAM loaded on {DEVICE}")
    return sam_predictor


def image_to_base64(image: Image.Image) -> str:
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return base64.b64encode(buffer.getvalue()).decode("utf-8")


def base64_to_image(data: str) -> Image.Image:
    if "," in data:
        data = data.split(",", 1)[1]
    return Image.open(io.BytesIO(base64.b64decode(data))).convert("RGBA")


def bytes_to_rgba(image_bytes: bytes) -> Image.Image:
    return Image.open(io.BytesIO(image_bytes)).convert("RGBA")


def rgba_to_png_response(image: Image.Image, detections=None) -> Response:
    output = io.BytesIO()
    image.save(output, format="PNG")
    output.seek(0)

    headers = {}

    if detections is not None:
        headers["x-detections"] = json.dumps(detections)

    return Response(
        content=output.getvalue(),
        media_type="image/png",
        headers=headers,
    )


def alpha_bbox(image: Image.Image) -> Tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()

    if bbox is None:
        return (0, 0, image.width, image.height)

    return bbox


def clamp_box(box, image):
    x1, y1, x2, y2 = [int(float(v)) for v in box]

    x1 = max(0, min(image.width - 1, x1))
    y1 = max(0, min(image.height - 1, y1))
    x2 = max(1, min(image.width, x2))
    y2 = max(1, min(image.height, y2))

    if x2 <= x1:
        x2 = min(image.width, x1 + 10)
    if y2 <= y1:
        y2 = min(image.height, y1 + 10)

    return [x1, y1, x2, y2]


def expand_box(box, image, px=10):
    x1, y1, x2, y2 = clamp_box(box, image)

    return clamp_box(
        [
            x1 - px,
            y1 - px,
            x2 + px,
            y2 + px,
        ],
        image,
    )


def normalize_car_canvas(
    image: Image.Image,
    canvas_width: int = 1024,
    canvas_height: int = 768,
    target_width_ratio: float = 0.88,
    target_height_ratio: float = 0.68,
) -> Image.Image:
    image = image.convert("RGBA")
    x1, y1, x2, y2 = alpha_bbox(image)

    car_crop = image.crop((x1, y1, x2, y2))

    scale = min(
        (canvas_width * target_width_ratio) / max(1, car_crop.width),
        (canvas_height * target_height_ratio) / max(1, car_crop.height),
    )

    new_width = max(1, int(car_crop.width * scale))
    new_height = max(1, int(car_crop.height * scale))

    car_crop = car_crop.resize((new_width, new_height), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (canvas_width, canvas_height), (0, 0, 0, 0))

    paste_x = (canvas_width - new_width) // 2
    paste_y = int(canvas_height * 0.62) - (new_height // 2)
    paste_y = max(20, min(canvas_height - new_height - 20, paste_y))

    canvas.paste(car_crop, (paste_x, paste_y), car_crop)

    return canvas


def parse_rgb(prompt: str, default=(60, 140, 255)):
    values = re.findall(r"\d+", prompt)

    if len(values) >= 3:
        return (
            max(0, min(255, int(values[0]))),
            max(0, min(255, int(values[1]))),
            max(0, min(255, int(values[2]))),
        )

    return default


def detect_vehicle_view(image: Image.Image) -> str:
    x1, y1, x2, y2 = alpha_bbox(image)

    width = x2 - x1
    height = y2 - y1

    ratio = width / max(1, height)

    if ratio > 2.05:
        return "side"

    if ratio > 1.35:
        return "front_side"

    if ratio > 1.05:
        return "front_or_rear"

    return "unknown"


def vehicle_zones(image: Image.Image):
    view = detect_vehicle_view(image)

    x1, y1, x2, y2 = alpha_bbox(image)

    width = x2 - x1
    height = y2 - y1

    print("DETECTED VIEW:", view)

    if view == "side":
        front_wheel_x = 0.78
        rear_wheel_x = 0.22
        windows = [0.18, 0.11, 0.75, 0.42]
        left_light = [0.76, 0.42, 0.92, 0.54]
        right_light = [0.06, 0.42, 0.20, 0.54]
        grille = [0.72, 0.48, 0.92, 0.72]

    elif view == "front_side":
        front_wheel_x = 0.62
        rear_wheel_x = 0.20
        windows = [0.20, 0.12, 0.74, 0.42]
        left_light = [0.48, 0.43, 0.68, 0.56]
        right_light = [0.80, 0.43, 0.94, 0.56]
        grille = [0.62, 0.47, 0.88, 0.72]

    elif view == "front_or_rear":
        front_wheel_x = 0.62
        rear_wheel_x = 0.32
        windows = [0.24, 0.12, 0.76, 0.40]
        left_light = [0.18, 0.42, 0.38, 0.56]
        right_light = [0.62, 0.42, 0.82, 0.56]
        grille = [0.34, 0.45, 0.66, 0.72]

    else:
        front_wheel_x = 0.62
        rear_wheel_x = 0.20
        windows = [0.20, 0.12, 0.74, 0.42]
        left_light = [0.48, 0.43, 0.68, 0.56]
        right_light = [0.80, 0.43, 0.94, 0.56]
        grille = [0.62, 0.47, 0.88, 0.72]

    front_wheel_radius = max(24, int(width * 0.085))
    rear_wheel_radius = max(24, int(width * 0.075))

    return {
        "body_box": [
            x1 + int(width * 0.03),
            y1 + int(height * 0.08),
            x2 - int(width * 0.03),
            y1 + int(height * 0.90),
        ],
        "front_wheel_box": [
            x1 + int(width * front_wheel_x) - front_wheel_radius,
            y1 + int(height * 0.76) - front_wheel_radius,
            x1 + int(width * front_wheel_x) + front_wheel_radius,
            y1 + int(height * 0.76) + front_wheel_radius,
        ],
        "rear_wheel_box": [
            x1 + int(width * rear_wheel_x) - rear_wheel_radius,
            y1 + int(height * 0.77) - rear_wheel_radius,
            x1 + int(width * rear_wheel_x) + rear_wheel_radius,
            y1 + int(height * 0.77) + rear_wheel_radius,
        ],
        "windows_box": [
            x1 + int(width * windows[0]),
            y1 + int(height * windows[1]),
            x1 + int(width * windows[2]),
            y1 + int(height * windows[3]),
        ],
        "left_light_box": [
            x1 + int(width * left_light[0]),
            y1 + int(height * left_light[1]),
            x1 + int(width * left_light[2]),
            y1 + int(height * left_light[3]),
        ],
        "right_light_box": [
            x1 + int(width * right_light[0]),
            y1 + int(height * right_light[1]),
            x1 + int(width * right_light[2]),
            y1 + int(height * right_light[3]),
        ],
        "grille_box": [
            x1 + int(width * grille[0]),
            y1 + int(height * grille[1]),
            x1 + int(width * grille[2]),
            y1 + int(height * grille[3]),
        ],
    }


def create_detection(image: Image.Image):
    zones = vehicle_zones(image)

    detections = []

    for part_name, box_name in [
        ("body", "body_box"),
        ("front_wheel", "front_wheel_box"),
        ("rear_wheel", "rear_wheel_box"),
        ("windows", "windows_box"),
        ("left_light", "left_light_box"),
        ("right_light", "right_light_box"),
        ("grille", "grille_box"),
    ]:
        detections.append({
            "part": part_name,
            "box": clamp_box(zones[box_name], image),
            "mask_poly": [],
        })

    return detections


def get_box_from_part(parts, part_name, fallback_box):
    try:
        for item in parts:
            if item.get("part") == part_name:
                box = item.get("box", fallback_box)

                if isinstance(box, list) and len(box) == 4:
                    return [int(float(v)) for v in box]
    except Exception:
        pass

    return fallback_box


def get_part_box(parts, part_name):
    for item in parts:
        if item.get("part") == part_name:
            return item.get("box")
    return None


def add_or_replace_part(parts, part_name, box, image):
    box = clamp_box(box, image)

    for item in parts:
        if item.get("part") == part_name:
            item["box"] = box
            return

    parts.append({
        "part": part_name,
        "box": box,
        "mask_poly": [],
    })


def box_size(box):
    x1, y1, x2, y2 = [int(float(v)) for v in box]
    return max(0, x2 - x1), max(0, y2 - y1)


def is_bad_box(box, image, part_name):
    w, h = box_size(box)

    if part_name in ["left_light", "right_light"]:
        return w < image.width * 0.035 or h < image.height * 0.020

    if part_name == "windows":
        return w < image.width * 0.14 or h < image.height * 0.045

    if part_name in ["front_wheel", "rear_wheel"]:
        return h < image.height * 0.05

    if part_name == "grille":
        return w < image.width * 0.07 or h < image.height * 0.035

    if part_name == "body":
        return w < image.width * 0.45 or h < image.height * 0.22

    return False


def fix_wheel_box(box, image):
    x1, y1, x2, y2 = clamp_box(box, image)

    w = x2 - x1
    h = y2 - y1

    cx = (x1 + x2) / 2
    cy = (y1 + y2) / 2

    size = max(w, h)
    size = max(size, int(image.width * 0.11))

    new_x1 = cx - size / 2
    new_x2 = cx + size / 2
    new_y1 = cy - size / 2
    new_y2 = cy + size / 2

    fixed = clamp_box([new_x1, new_y1, new_x2, new_y2], image)

    print("FIXED WHEEL BOX")
    print("OLD:", box)
    print("NEW:", fixed)

    return fixed


def replace_bad_boxes_with_fallbacks(image, parts):
    fallback = create_detection(image)

    fallback_map = {
        item["part"]: item["box"]
        for item in fallback
    }

    if not isinstance(parts, list):
        return fallback

    fixed_parts = []

    for item in parts:
        if not isinstance(item, dict):
            continue

        part_name = item.get("part")
        box = item.get("box")

        if not part_name or not box:
            continue

        if part_name in ["front_wheel", "rear_wheel"]:
            item["box"] = fix_wheel_box(box, image)
            fixed_parts.append(item)
            continue

        if is_bad_box(box, image, part_name):
            if part_name in ["body", "windows"]:
                print(f"BAD BOX DETECTED for {part_name}. Using fallback:", box)
                item["box"] = fallback_map.get(part_name, box)
                fixed_parts.append(item)
            else:
                print(f"BAD BOX DETECTED for {part_name}. Keeping visible-only part:", box)
                fixed_parts.append(item)
            continue

        fixed_parts.append(item)

    return fixed_parts

def merge_box(box_a, box_b, image):
    return clamp_box(
        [
            min(box_a[0], box_b[0]),
            min(box_a[1], box_b[1]),
            max(box_a[2], box_b[2]),
            max(box_a[3], box_b[3]),
        ],
        image,
    )

def improve_detection_with_fallbacks(image, mapped):
    fallback = create_detection(image)

    fallback_map = {
        item["part"]: item["box"]
        for item in fallback
    }

    detected_map = {}

    for item in mapped:
        if not isinstance(item, dict):
            continue

        part_name = item.get("part")
        box = item.get("box")

        if not part_name or not box:
            continue

        if part_name in fallback_map and not is_bad_box(box, image, part_name):
            detected_map[part_name] = clamp_box(box, image)

    clean = []

    required_fallback_parts = [
        "body",
        "windows",
    ]

    visible_only_parts = [
        "front_wheel",
        "rear_wheel",
        "left_light",
        "right_light",
        "grille",
    ]

    for part_name in required_fallback_parts:
        if part_name in detected_map:
            final_box = detected_map[part_name]
            source = "ROBOFLOW"
        else:
            final_box = clamp_box(fallback_map[part_name], image)
            source = "FALLBACK"

        clean.append({
            "part": part_name,
            "box": final_box,
            "mask_poly": [],
        })

        print(f"{part_name} box source: {source} -> {final_box}")

    for part_name in visible_only_parts:
        if part_name not in detected_map:
            print(f"{part_name} not clearly detected. Skipping, no fallback guess.")
            continue

        final_box = detected_map[part_name]

        clean.append({
            "part": part_name,
            "box": final_box,
            "mask_poly": [],
        })

        print(f"{part_name} box source: ROBOFLOW_VISIBLE -> {final_box}")

    print("IMPROVED DETECTION USED:")
    print(clean)

    return clean


def roboflow_detect_parts(image):
    try:
        from inference_sdk import InferenceHTTPClient

        print("Using Roboflow SDK...")

        api_key = os.getenv("ROBOFLOW_API_KEY")
        if not api_key:
            print("ROBOFLOW_API_KEY not set. Falling back.")
            return create_detection(image)

        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as temp:
            temp_path = temp.name
            image.convert("RGB").save(temp_path)

        client = InferenceHTTPClient(
            api_url="https://serverless.roboflow.com",
            api_key=api_key,
        )

        result = client.run_workflow(
            workspace_name="yuris-workspace-t8bqo",
            workflow_id="detect-count-and-visualize",
            images={"image": temp_path},
            use_cache=True,
        )

        print("RAW ROBOFLOW RESULT:", result)

        if os.path.exists(temp_path):
            os.remove(temp_path)

        first_result = result[0]

        if "output" in first_result:
            predictions = first_result["output"]
        elif (
            "predictions" in first_result
            and "predictions" in first_result["predictions"]
        ):
            predictions = first_result["predictions"]["predictions"]
        else:
            print("Unknown Roboflow response format")
            return create_detection(image)

        mapped = []

        for p in predictions:
            cls = p.get("class", "").upper()

            x = float(p["x"])
            y = float(p["y"])
            w = float(p["width"])
            h = float(p["height"])

            x1 = int(x - w / 2)
            y1 = int(y - h / 2)
            x2 = int(x + w / 2)
            y2 = int(y + h / 2)

            part_name = None

            if "WHEEL" in cls or "RIM" in cls or "TIRE" in cls or "TYRE" in cls:
                x1 -= 18
                y1 -= 18
                x2 += 18
                y2 += 18

                if x < image.width / 2:
                    part_name = "rear_wheel"
                else:
                    part_name = "front_wheel"

            elif "HEADLIGHT-L" in cls:
                x1 += 8
                y1 += 8
                x2 -= 8
                y2 -= 8
                part_name = "left_light"

            elif "HEADLIGHT-R" in cls:
                x1 += 8
                y1 += 8
                x2 -= 8
                y2 -= 8
                part_name = "right_light"

            elif "HEADLIGHT" in cls or "LIGHT" in cls:
                x1 += 8
                y1 += 8
                x2 -= 8
                y2 -= 8

                if x < image.width / 2:
                    part_name = "left_light"
                else:
                    part_name = "right_light"

            elif "WINDSHIELD" in cls or "WINDSCREEN" in cls or "WINDOW" in cls:
                x1 += 10
                y1 += 10
                x2 -= 10
                y2 -= 8
                part_name = "windows"

            elif "GRILLE" in cls or "GRILL" in cls:
                x1 -= 10
                y1 -= 10
                x2 += 10
                y2 += 10
                part_name = "grille"

            elif (
                "BUMPER" in cls
                or "HOOD" in cls
                or "BONNET" in cls
                or "DOOR" in cls
                or "FENDER" in cls
                or "BODY" in cls
            ):
                x1 -= 55
                y1 -= 45
                x2 += 55
                y2 += 45
                part_name = "body"

            if part_name is None:
                continue

            box = clamp_box([x1, y1, x2, y2], image)
            existing = get_part_box(mapped, part_name)

            if existing:
                add_or_replace_part(
                    mapped,
                    part_name,
                    merge_box(existing, box, image),
                    image,
                )
            else:
                add_or_replace_part(mapped, part_name, box, image)

        mapped = improve_detection_with_fallbacks(image, mapped)

        print("ROBOFLOW SDK USED SUCCESSFULLY:")
        print(mapped)

        return mapped

    except Exception as e:
        print("Roboflow detection failed:", e)
        return create_detection(image)


def clean_rembg_alpha(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    arr = np.array(image)

    alpha = arr[:, :, 3]

    arr[alpha < 180, 3] = 0
    arr[alpha >= 180, 3] = 255

    return Image.fromarray(arr, "RGBA")


def rectangle_mask(image: Image.Image, box, rounded=False, radius=14):
    mask = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(mask)

    box = clamp_box(box, image)

    if rounded:
        draw.rounded_rectangle(box, radius=radius, fill=255)
    else:
        draw.rectangle(box, fill=255)

    return mask


def oval_mask(image: Image.Image, box, blur=3):
    mask = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(mask)

    box = clamp_box(box, image)
    draw.ellipse(box, fill=255)

    if blur > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(blur))

    return mask


def combine_pil_masks(masks):
    if not masks:
        return None

    result = Image.new("L", masks[0].size, 0)

    for mask in masks:
        result = Image.fromarray(
            np.maximum(np.array(result), np.array(mask))
        ).convert("L")

    return result


def pixel_mask_from_box(
    image: Image.Image,
    box,
    mode="general",
    threshold_alpha=20,
):
    image = image.convert("RGBA")
    arr = np.array(image)

    x1, y1, x2, y2 = clamp_box(box, image)
    crop = arr[y1:y2, x1:x2]

    mask_np = np.zeros((image.height, image.width), dtype=np.uint8)

    if crop.size == 0:
        return mask_np

    alpha = crop[:, :, 3]
    rgb = crop[:, :, :3].astype(np.float32)

    brightness = rgb.mean(axis=2)
    max_c = rgb.max(axis=2)
    min_c = rgb.min(axis=2)
    saturation = max_c - min_c

    if mode == "windows":
        foreground = (
            (alpha > threshold_alpha)
            & (brightness > 15)
            & (brightness < 185)
            & (saturation > 4)
        )

    elif mode == "lights":
        foreground = (
            (alpha > threshold_alpha)
            & (brightness > 65)
            & (brightness < 255)
        )

    elif mode == "body":
        foreground = (
            (alpha > threshold_alpha)
            & (brightness > 20)
            & (brightness < 245)
        )

    elif mode == "wheels":
        foreground = (
            (alpha > threshold_alpha)
            & (brightness > 5)
            & (brightness < 230)
        )

    else:
        foreground = (
            (alpha > threshold_alpha)
            & (brightness > 18)
            & (brightness < 248)
        )

    mask_np[y1:y2, x1:x2] = foreground.astype(np.uint8) * 255

    return mask_np


def sam_mask_from_box(image: Image.Image, box, blur=0):
    predictor = load_sam()

    rgb_image = np.array(image.convert("RGB"))
    predictor.set_image(rgb_image)

    box = clamp_box(box, image)
    box_np = np.array(box, dtype=np.float32)

    masks, scores, _ = predictor.predict(
        box=box_np,
        multimask_output=True,
    )

    best_mask = masks[int(np.argmax(scores))]
    mask_np = best_mask.astype(np.uint8) * 255

    if blur > 0:
        mask_np = cv2.GaussianBlur(mask_np, (blur * 2 + 1, blur * 2 + 1), 0)

    return mask_np

def mask_to_polygon(mask_np, epsilon_ratio=0.01):
    contours, _ = cv2.findContours(
        mask_np,
        cv2.RETR_EXTERNAL,
        cv2.CHAIN_APPROX_SIMPLE,
    )

    polygons = []

    for contour in contours:
        area = cv2.contourArea(contour)

        if area < 120:
            continue

        epsilon = epsilon_ratio * cv2.arcLength(contour, True)

        approx = cv2.approxPolyDP(
            contour,
            epsilon,
            True,
        )

        polygon = []

        for point in approx:
            x, y = point[0]
            polygon.append([int(x), int(y)])

        if len(polygon) >= 3:
            polygons.append(polygon)

    return polygons

def mask_from_part_polygon(image: Image.Image, part_item):
    if not isinstance(part_item, dict):
        return None

    polygons = part_item.get("mask_poly", [])

    if not polygons:
        return None

    mask = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(mask)

    for polygon in polygons:
        if not isinstance(polygon, list):
            continue

        if len(polygon) < 3:
            continue

        try:
            points = [(int(point[0]), int(point[1])) for point in polygon]
            draw.polygon(points, fill=255)
        except Exception:
            continue

    if mask.getbbox() is None:
        return None

    return mask.filter(ImageFilter.GaussianBlur(2))


def get_part_item(parts, part_name):
    if not isinstance(parts, list):
        return None

    for item in parts:
        if not isinstance(item, dict):
            continue

        if item.get("part") == part_name:
            return item

    return None


def smart_part_mask(image: Image.Image, parts, part_name, fallback_box, mode="general"):
    item = get_part_item(parts, part_name)

    if item:
        box = item.get("box", fallback_box)
    else:
        box = fallback_box

    return refined_mask_from_box(
        image,
        box,
        blur=3,
        threshold_alpha=20,
        min_area_ratio=0.001,
        mode=mode,
        use_sam=False,
    )

def restrict_mask_to_box(mask_np, image, box, padding=8):
    x1, y1, x2, y2 = expand_box(box, image, px=padding)

    restricted = np.zeros_like(mask_np, dtype=np.uint8)
    restricted[y1:y2, x1:x2] = mask_np[y1:y2, x1:x2]

    return restricted


def refined_mask_from_box(
    image: Image.Image,
    box,
    blur=5,
    threshold_alpha=20,
    min_area_ratio=0.002,
    mode="general",
    use_sam=True,
):
    image = image.convert("RGBA")
    arr = np.array(image)

    box = clamp_box(box, image)

    pixel_mask = pixel_mask_from_box(
        image,
        box,
        mode=mode,
        threshold_alpha=threshold_alpha,
    )

    final_mask = pixel_mask

    if use_sam:
        try:
            sam_mask = sam_mask_from_box(image, box, blur=0)
            sam_mask = restrict_mask_to_box(sam_mask, image, box, padding=10)

            if mode in ["windows", "lights"]:
                final_mask = np.minimum(sam_mask, pixel_mask)
            elif mode == "body":
                final_mask = np.maximum(sam_mask, pixel_mask)
                final_mask = restrict_mask_to_box(final_mask, image, box, padding=2)
            else:
                final_mask = sam_mask

        except Exception as e:
            print("SAM unavailable. Using pixel mask only:", e)
            final_mask = pixel_mask

    alpha_full = arr[:, :, 3]
    final_mask = np.where(alpha_full > threshold_alpha, final_mask, 0).astype(np.uint8)

    found_area = int(np.sum(final_mask > 20))
    full_area = image.width * image.height

    if found_area < full_area * min_area_ratio:
        print(f"{mode} mask too small. Using soft search-area fallback.")
        fallback = np.zeros((image.height, image.width), dtype=np.uint8)
        x1, y1, x2, y2 = clamp_box(box, image)

        if mode == "wheels":
            temp = Image.new("L", image.size, 0)
            draw = ImageDraw.Draw(temp)
            draw.ellipse([x1, y1, x2, y2], fill=210)
            fallback = np.array(temp).astype(np.uint8)
        else:
            temp = Image.new("L", image.size, 0)
            draw = ImageDraw.Draw(temp)
            draw.rounded_rectangle([x1, y1, x2, y2], radius=18, fill=160)
            fallback = np.array(temp).astype(np.uint8)

        final_mask = np.where(alpha_full > threshold_alpha, fallback, 0).astype(np.uint8)

    kernel = np.ones((5, 5), np.uint8)
    final_mask = cv2.morphologyEx(final_mask, cv2.MORPH_CLOSE, kernel, iterations=2)
    final_mask = cv2.morphologyEx(final_mask, cv2.MORPH_OPEN, kernel, iterations=1)

    if blur > 0:
        final_mask = cv2.GaussianBlur(final_mask, (blur * 2 + 1, blur * 2 + 1), 0)

    return Image.fromarray(final_mask).convert("L")


def protect_parts_mask(image: Image.Image, parts, exclude=None):
    if exclude is None:
        exclude = []

    protected = Image.new("L", image.size, 0)

    if not isinstance(parts, list):
        return protected

    for item in parts:
        if not isinstance(item, dict):
            continue

        part_name = item.get("part")

        if part_name in exclude:
            continue

        if part_name not in [
            "windows",
            "left_light",
            "right_light",
            "front_wheel",
            "rear_wheel",
            "grille",
        ]:
            continue

        box = item.get("box")

        if not box:
            continue

        if part_name in ["front_wheel", "rear_wheel"]:
            mask = oval_mask(image, box, blur=3)
        elif part_name == "windows":
            mask = refined_mask_from_box(
                image,
                box,
                blur=2,
                threshold_alpha=20,
                min_area_ratio=0.0005,
                mode="windows",
                use_sam=False,
            )
        elif part_name in ["left_light", "right_light"]:
            mask = refined_mask_from_box(
                image,
                box,
                blur=2,
                threshold_alpha=20,
                min_area_ratio=0.0002,
                mode="lights",
                use_sam=False,
            )
        else:
            mask = refined_mask_from_box(
                image,
                box,
                blur=2,
                threshold_alpha=20,
                min_area_ratio=0.0005,
                mode="general",
                use_sam=False,
            )

        protected = Image.fromarray(
            np.maximum(np.array(protected), np.array(mask))
        ).convert("L")

    return protected.filter(ImageFilter.GaussianBlur(2))


def subtract_mask(base: Image.Image, remove_mask: Image.Image):
    base_np = np.array(base).astype(np.uint8)
    remove_np = np.array(remove_mask).astype(np.uint8)

    result = np.where(remove_np > 20, 0, base_np).astype(np.uint8)

    return Image.fromarray(result).convert("L")


def paint_body(image: Image.Image, rgb, parts):
    zones = vehicle_zones(image)

    original = image.convert("RGBA")
    arr = np.array(original).astype(np.float32)

    body_mask = smart_part_mask(
        image,
        parts,
        "body",
        zones["body_box"],
        mode="body",
    )

    protected = protect_parts_mask(
        image,
        parts,
        exclude=["body"],
    )

    body_mask = subtract_mask(body_mask, protected)
    body_mask = body_mask.filter(ImageFilter.GaussianBlur(radius=4))

    mask_np = np.array(body_mask).astype(np.float32) / 255.0
    mask_np = np.clip(mask_np, 0, 1)

    luminance = (
        0.299 * arr[:, :, 0]
        + 0.587 * arr[:, :, 1]
        + 0.114 * arr[:, :, 2]
    ) / 255.0

    target = np.array(rgb, dtype=np.float32)

    shaded_colour = target * np.expand_dims(
        np.clip(luminance * 1.25, 0.20, 1.25),
        axis=2,
    )

    highlight = np.expand_dims(
        np.clip((luminance - 0.50) * 2.2, 0, 1),
        axis=2,
    ) * 42

    shaded_colour = np.clip(shaded_colour + highlight, 0, 255)

    mask_3 = np.expand_dims(mask_np, axis=2)

    recoloured = (arr[:, :, :3] * 0.42) + (shaded_colour * 0.58)

    result_rgb = (
        arr[:, :, :3] * (1 - mask_3)
        + recoloured * mask_3
    )

    result = np.dstack([
        np.clip(result_rgb, 0, 255),
        arr[:, :, 3],
    ]).astype(np.uint8)

    return Image.fromarray(result, "RGBA")


def tint_windows(image: Image.Image, rgb, parts):
    zones = vehicle_zones(image)

    mask = smart_part_mask(
        image,
        parts,
        "windows",
        zones["windows_box"],
        mode="windows",
    )

    if mask.getbbox() is None:
        print("Window mask empty. Skipping window tint.")
        return image.convert("RGBA")

    original = image.convert("RGBA")

    dark_layer = Image.new("RGBA", image.size, (2, 6, 10, 95))
    tint_layer = Image.new("RGBA", image.size, (*rgb, 60))

    result = Image.composite(dark_layer, original, mask)
    result = Image.alpha_composite(original, result)

    result2 = Image.composite(tint_layer, result, mask)
    result = Image.alpha_composite(result, result2)

    return result


def light_effect(image: Image.Image, rgb, part_item):
    original = image.convert("RGBA")

    if not isinstance(part_item, dict):
        print("Invalid light part item. Skipping.")
        return original

    box = part_item.get("box")

    if not box:
        print("Light has no box. Skipping.")
        return original

    mask = refined_mask_from_box(
        image,
        box,
        blur=2,
        threshold_alpha=20,
        min_area_ratio=0.0002,
        mode="lights",
        use_sam=False,
    )

    if mask.getbbox() is None:
        print("Light mask empty. Skipping light effect.")
        return original

    glow = mask.filter(ImageFilter.GaussianBlur(14))

    glow_overlay = Image.new("RGBA", image.size, (*rgb, 75))
    core_overlay = Image.new("RGBA", image.size, (*rgb, 165))

    temp = Image.composite(glow_overlay, original, glow)
    temp = Image.alpha_composite(original, temp)

    result = Image.composite(core_overlay, temp, mask)
    result = Image.alpha_composite(temp, result)

    return result


def lights_effect_all_visible(image: Image.Image, rgb, parts):
    result = image.convert("RGBA")

    for part_name in ["left_light", "right_light"]:
        part_item = get_part_item(parts, part_name)

        if part_item is None:
            print(f"{part_name} not found. Skipping.")
            continue

        result = light_effect(result, rgb, part_item)

    return result


def draw_sport_wheel(image: Image.Image, box, style: str):
    result = image.convert("RGBA").copy()
    draw = ImageDraw.Draw(result, "RGBA")

    x1, y1, x2, y2 = [int(float(v)) for v in box]
    cx = (x1 + x2) // 2
    cy = (y1 + y2) // 2

    radius = int(max(16, max(x2 - x1, y2 - y1) // 2) * 0.65)
    tyre_r = radius
    rim_r = int(radius * 0.60)

    style = style.upper()

    tyre_box = [cx - tyre_r, cy - tyre_r, cx + tyre_r, cy + tyre_r]
    rim_box = [cx - rim_r, cy - rim_r, cx + rim_r, cy + rim_r]

    draw.ellipse(tyre_box, fill=(5, 5, 5, 255), outline=(0, 0, 0, 255), width=5)
    draw.ellipse(
        [
            cx - int(radius * 0.86),
            cy - int(radius * 0.86),
            cx + int(radius * 0.86),
            cy + int(radius * 0.86),
        ],
        outline=(35, 35, 35, 240),
        width=5,
    )

    if "OFF ROAD" in style:
        rim_colour = (25, 25, 25, 255)
        spoke_colour = (120, 120, 120, 255)
        spoke_count = 6
        rim_r = int(radius * 0.58)

    elif "VINTAGE" in style:
        rim_colour = (190, 185, 170, 255)
        spoke_colour = (245, 240, 220, 255)
        spoke_count = 16

    elif "DEEP DISH" in style:
        rim_colour = (20, 20, 24, 255)
        spoke_colour = (215, 215, 220, 255)
        spoke_count = 10
        draw.ellipse(
            [
                cx - int(radius * 0.72),
                cy - int(radius * 0.72),
                cx + int(radius * 0.72),
                cy + int(radius * 0.72),
            ],
            fill=(15, 15, 18, 255),
            outline=(230, 230, 230, 240),
            width=4,
        )

    else:
        rim_colour = (38, 38, 42, 255)
        spoke_colour = (205, 205, 210, 255)
        spoke_count = 8

    draw.ellipse(rim_box, fill=rim_colour, outline=(225, 225, 225, 245), width=3)

    for i in range(spoke_count):
        angle = (2 * np.pi * i) / spoke_count

        sx = cx + int(np.cos(angle) * rim_r * 0.18)
        sy = cy + int(np.sin(angle) * rim_r * 0.18)
        ex = cx + int(np.cos(angle) * rim_r * 0.92)
        ey = cy + int(np.sin(angle) * rim_r * 0.92)

        draw.line(
            [sx, sy, ex, ey],
            fill=spoke_colour,
            width=max(2, radius // 11),
        )

    centre = max(5, radius // 7)
    draw.ellipse(
        [cx - centre, cy - centre, cx + centre, cy + centre],
        fill=(12, 12, 12, 255),
        outline=(240, 240, 240, 255),
        width=2,
    )

    draw.arc(
        [cx - radius + 8, cy - radius + 8, cx + radius - 8, cy + radius - 8],
        start=205,
        end=315,
        fill=(255, 255, 255, 80),
        width=3,
    )

    return result


def wheel_effect(image: Image.Image, style: str, parts):
    zones = vehicle_zones(image)

    front_box = get_box_from_part(parts, "front_wheel", zones["front_wheel_box"])
    rear_box = get_box_from_part(parts, "rear_wheel", zones["rear_wheel_box"])

    result = image.convert("RGBA").copy()

    front_mask = oval_mask(result, front_box, blur=2)
    rear_mask = oval_mask(result, rear_box, blur=2)

    front_draw = draw_sport_wheel(result, front_box, style)
    rear_draw = draw_sport_wheel(front_draw, rear_box, style)

    wheel_mask = combine_pil_masks([front_mask, rear_mask])

    result = Image.composite(
        rear_draw,
        result,
        wheel_mask,
    )

    return result


def suspension_effect(image: Image.Image, style: str):
    style = style.upper()

    if "LOW" in style:
        offset = 26
    elif "HIGH" in style:
        offset = -24
    else:
        offset = 0

    if offset == 0:
        return image

    image = image.convert("RGBA")

    arr = np.array(image)

    alpha = arr[:, :, 3]

    ys, xs = np.where(alpha > 10)

    if len(xs) == 0 or len(ys) == 0:
        return image

    x1 = np.min(xs)
    x2 = np.max(xs)
    y1 = np.min(ys)
    y2 = np.max(ys)

    crop = image.crop((x1, y1, x2, y2))

    canvas = Image.new(
        "RGBA",
        image.size,
        (0, 0, 0, 0),
    )

    paste_y = y1 + offset

    paste_y = max(
        0,
        min(image.height - crop.height, paste_y),
    )

    canvas.paste(crop, (x1, paste_y), crop)

    return canvas


def safe_rect(coords, image):
    x1, y1, x2, y2 = [int(float(v)) for v in coords]

    x1 = max(0, min(image.width - 1, x1))
    x2 = max(0, min(image.width - 1, x2))
    y1 = max(0, min(image.height - 1, y1))
    y2 = max(0, min(image.height - 1, y2))

    left = min(x1, x2)
    right = max(x1, x2)
    top = min(y1, y2)
    bottom = max(y1, y2)

    if right <= left:
        right = min(image.width - 1, left + 3)
    if bottom <= top:
        bottom = min(image.height - 1, top + 3)

    return [left, top, right, bottom]


def aero_effect(image: Image.Image, style: str, parts):
    style = style.upper()

    result = image.convert("RGBA").copy()
    draw = ImageDraw.Draw(result, "RGBA")
    car_x1, car_y1, car_x2, car_y2 = alpha_bbox(result)

    car_width = max(10, car_x2 - car_x1)
    car_height = max(10, car_y2 - car_y1)

    zones = vehicle_zones(result)

    front_wheel = get_box_from_part(parts, "front_wheel", zones["front_wheel_box"])
    rear_wheel = get_box_from_part(parts, "rear_wheel", zones["rear_wheel_box"])

    fw1, fy1, fw2, fy2 = [int(float(v)) for v in front_wheel]
    rw1, ry1, rw2, ry2 = [int(float(v)) for v in rear_wheel]

    carbon = (5, 5, 5, 220)
    carbon_soft = (18, 18, 18, 190)
    highlight = (160, 160, 160, 120)

    wheel_bottom = max(fy2, ry2)
    body_bottom = car_y2
    bottom_y = min(max(wheel_bottom - 8, body_bottom - int(car_height * 0.08)), car_y2 + 8)

    if "SPLITTER" in style or "BODY KIT" in style:
        splitter_x1 = car_x2 - int(car_width * 0.34)
        splitter_x2 = car_x2 - int(car_width * 0.02)
        splitter_y = bottom_y - int(car_height * 0.06)

        points = [
            (splitter_x1, splitter_y),
            (splitter_x2, splitter_y - 4),
            (splitter_x2 + 10, splitter_y + 12),
            (splitter_x1 - 16, splitter_y + 16),
        ]

        draw.polygon(points, fill=carbon)
        draw.line([points[0], points[1]], fill=highlight, width=2)

    if "DIFFUSER" in style or "BODY KIT" in style:
        diffuser_x1 = car_x1 + int(car_width * 0.02)
        diffuser_x2 = car_x1 + int(car_width * 0.30)
        diffuser_y = bottom_y - int(car_height * 0.045)

        points = [
            (diffuser_x1, diffuser_y),
            (diffuser_x2, diffuser_y - 3),
            (diffuser_x2 + 8, diffuser_y + 15),
            (diffuser_x1 - 5, diffuser_y + 15),
        ]

        draw.polygon(points, fill=carbon)

        fin_count = 3
        for i in range(fin_count):
            fin_x = diffuser_x1 + 18 + i * 24
            draw.polygon(
                [
                    (fin_x, diffuser_y + 3),
                    (fin_x + 6, diffuser_y + 3),
                    (fin_x + 11, diffuser_y + 15),
                    (fin_x - 3, diffuser_y + 15),
                ],
                fill=(0, 0, 0, 230),
            )

    if "BODY KIT" in style:
        skirt_x1 = min(rw2, fw2) + 8
        skirt_x2 = max(rw1, fw1) - 8

        if skirt_x2 > skirt_x1:
            skirt_y1 = bottom_y - 14
            skirt_y2 = bottom_y + 5

            skirt_rect = safe_rect(
                [skirt_x1, skirt_y1, skirt_x2, skirt_y2],
                result,
            )

            draw.rounded_rectangle(
                skirt_rect,
                radius=5,
                fill=carbon_soft,
            )

            draw.line(
                [
                    (skirt_rect[0] + 8, skirt_rect[1] + 4),
                    (skirt_rect[2] - 8, skirt_rect[1] + 4),
                ],
                fill=highlight,
                width=2,
            )

    if "SPOILER" in style or "BODY KIT" in style:
        spoiler_x1 = car_x1 + int(car_width * 0.03)
        spoiler_x2 = car_x1 + int(car_width * 0.23)
        spoiler_y = car_y1 + int(car_height * 0.22)

        spoiler_rect = safe_rect(
            [spoiler_x1, spoiler_y, spoiler_x2, spoiler_y + 8],
            result,
        )

        draw.rounded_rectangle(
            spoiler_rect,
            radius=4,
            fill=carbon,
        )

        draw.line(
            [
                (spoiler_rect[0] + 4, spoiler_rect[1] + 2),
                (spoiler_rect[2] - 4, spoiler_rect[1] + 2),
            ],
            fill=highlight,
            width=1,
        )

    return result

def run_forge_inpainting(image: Image.Image, mask: Image.Image, prompt: str):
    try:
        payload = {
            "init_images": [image_to_base64(image.convert("RGB"))],
            "mask": image_to_base64(mask.convert("L")),
            "prompt": prompt,
            "negative_prompt": "bad quality, blurry, distorted car, changed body shape",
            "denoising_strength": 0.45,
            "steps": 18,
            "cfg_scale": 7,
            "width": image.width,
            "height": image.height,
            "inpaint_full_res": False,
            "inpainting_mask_invert": 0,
        }

        response = requests.post(FORGE_IMG2IMG_URL, json=payload, timeout=90)
        response.raise_for_status()

        result = response.json()
        images = result.get("images", [])

        if not images:
            print("Forge returned no image. Using fallback.")
            return image

        return base64_to_image(images[0])

    except Exception as e:
        print("Forge inpainting failed. Using normal fallback:", e)
        return image


@app.post("/process-car")
async def process_car(image: UploadFile = File(...)):
    try:
        print("PROCESS CAR STARTED", flush=True)

        from rembg import remove

        image_bytes = await image.read()
        print("IMAGE BYTES READ:", len(image_bytes), flush=True)

        try:
            print("REMOVING BACKGROUND...", flush=True)

            session = load_rembg_session()

            removed = remove(
                image_bytes,
                session=session,
                alpha_matting=False,
                post_process_mask=True,
            )

            car = bytes_to_rgba(removed)
            car = clean_rembg_alpha(car)

            print("BACKGROUND REMOVED", flush=True)

        except Exception as rembg_error:
            print("BACKGROUND REMOVAL FAILED:", rembg_error, flush=True)
            car = bytes_to_rgba(image_bytes)

        car = normalize_car_canvas(car)
        print("IMAGE NORMALISED", flush=True)

        detection = roboflow_detect_parts(car)

        print("Process car completed", flush=True)

        return rgba_to_png_response(car, detection)

    except Exception as error:
        print(f"Process Error: {error}", flush=True)
        return Response(content=f"Process error: {error}", status_code=500)

@app.post("/customize-wheel")
async def customize_car(
    image: UploadFile = File(...),
    prompt: str = Form(...),
    part: str = Form(default="{}"),
    box: str = Form(default="[]"),
    mask_poly: str = Form(default="[]"),
):
    try:
        image_bytes = await image.read()
        car = bytes_to_rgba(image_bytes)

        prompt_upper = prompt.upper()

        try:
            parts = json.loads(mask_poly)
            if not isinstance(parts, list):
                parts = []
        except Exception:
            parts = []

        try:
            selected_part = json.loads(part)
            if not isinstance(selected_part, dict):
                selected_part = {}
        except Exception:
            selected_part = {}

        try:
            selected_box = selected_part.get("box")
            if not selected_box:
                selected_box = json.loads(box)
        except Exception:
            selected_box = selected_part.get("box", [])

        if parts:
            print("USING FLUTTER / EYE BUTTON PARTS:")
            print(parts)
        else:
            print("No parts received. Running Roboflow detection inside customize...")
            parts = roboflow_detect_parts(car)

        parts = replace_bad_boxes_with_fallbacks(car, parts)

        selected_part_name = selected_part.get("part", "car")

        print("==============================")
        print("BACKEND CUSTOMISE")
        print("PROMPT:", prompt_upper)
        print("SELECTED PART:", selected_part_name)
        print("SELECTED BOX:", selected_box)

        if "PAINT_COLOR" in prompt_upper:
            rgb = parse_rgb(prompt_upper)

            body_part = next(
                (
                    p for p in parts
                    if isinstance(p, dict)
                    and p.get("part") == "body"
                    and p.get("mask_poly")
                ),
                None,
            )

            if body_part:
                print("PAINT USING BODY POLYGON MASK")
            else:
                print("PAINT BODY POLYGON NOT FOUND. USING BODY BOX FALLBACK.")

            car = paint_body(car, rgb, parts)

        elif "WINDOW_TINT" in prompt_upper:
            rgb = parse_rgb(prompt_upper, default=(5, 15, 25))

            window_part = next(
                (
                    p for p in parts
                    if isinstance(p, dict)
                    and p.get("part") == "windows"
                    and p.get("mask_poly")
                ),
                None,
            )

            if window_part:
                print("WINDOW TINT USING WINDOW POLYGON MASK")
            else:
                print("WINDOW POLYGON NOT FOUND. USING WINDOW BOX FALLBACK.")

            car = tint_windows(car, rgb, parts)

        elif "LIGHT_COLOR" in prompt_upper:
            rgb = parse_rgb(prompt_upper)

            light_part = next(
                (
                    p for p in parts
                    if isinstance(p, dict)
                    and p.get("part") in ["left_light", "right_light"]
                    and p.get("mask_poly")
                ),
                None,
            )

            if light_part:
                print("LIGHTS USING LIGHT POLYGON MASK")
            else:
                print("LIGHT POLYGON NOT FOUND. USING LIGHT BOX FALLBACK.")

            car = lights_effect_all_visible(car, rgb, parts)

        elif prompt_upper.startswith("AI_WHEELS"):
            car = wheel_effect(car, "WHEELS SPORT", parts)

            zones = vehicle_zones(car)

            front_box = get_box_from_part(
                parts,
                "front_wheel",
                zones["front_wheel_box"],
            )
            rear_box = get_box_from_part(
                parts,
                "rear_wheel",
                zones["rear_wheel_box"],
            )

            mask = combine_pil_masks([
                oval_mask(car, front_box, blur=3),
                oval_mask(car, rear_box, blur=3),
            ])

            car = run_forge_inpainting(
                car,
                mask,
                "same exact car, replace only the two visible wheels with realistic black sport alloy wheels, preserve car body, preserve headlights, preserve grille, photorealistic",
            )

        elif prompt_upper.startswith("AERO"):
            car = aero_effect(car, prompt_upper, parts)

        elif prompt_upper.startswith("WHEELS"):
            car = wheel_effect(car, prompt_upper, parts)

        elif prompt_upper.startswith("SUSPENSION"):
            car = suspension_effect(car, prompt_upper)

        return rgba_to_png_response(car)

    except Exception as error:
        print(f"Modification Error: {error}")
        return Response(content=f"Modification error: {error}", status_code=500)


if __name__ == "__main__":
    import asyncio

    print("Starting backend...")

    asyncio.set_event_loop_policy(asyncio.DefaultEventLoopPolicy())

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8010,
        reload=False,
        loop="asyncio",
    )