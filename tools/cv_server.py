"""CV server for the Detector module's remote backend.

POST /detect with a JPEG body. Reply:
    {"detections": [{"label": "cup", "confidence": 0.91, "box": [x0, y0, x1, y1]}]}
Box corners run 0..1 from the image's top left; labels are COCO class names.

GET /health: "ok" (Turn to fit asks this every few seconds; its hub piece is offered only while it answers).

POST /segment?box=x0,y0,x1,y1 with a JPEG body (box in pixels, e.g. YOLO's cup box).
Reply: a PNG mask the size of the picture, white = the object (MobileSAM, box prompt).
Used for Turn to fit's capture step (claude/CV_TURN_TO_FIT_BUILD.md). The MobileSAM
weights (40 MB) download once, into build/models/ (ignored by Git).

    pip install ultralytics onnxruntime
    python tools/cv_server.py                 # the headset's YOLO11n on 127.0.0.1:8765
    adb reverse tcp:8765 tcp:8765             # a USB-connected Quest reaches it as 127.0.0.1

--fake answers every frame with one centred "cup", for tests without a model.
"""

import argparse
import io
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

## The model the headset runs (modules/cv/detector.gd), so both give the same answers.
MODEL = str(Path(__file__).resolve().parents[1] / "modules" / "cv" / "yolo11n.onnx")


def yolo(weights):
    from PIL import Image
    from ultralytics import YOLO

    model = YOLO(weights, task="detect")

    def detect(jpeg):
        result = model(Image.open(io.BytesIO(jpeg)).convert("RGB"), verbose=False)[0]
        return [{"label": result.names[int(cls)], "confidence": round(score, 3),
                 "box": [round(value, 4) for value in box]}
                for box, score, cls in zip(result.boxes.xyxyn.tolist(), result.boxes.conf.tolist(),
                                           result.boxes.cls.tolist())]

    return detect


## MobileSAM's weights; Ultralytics downloads them here the first time.
SAM_WEIGHTS = Path(__file__).resolve().parents[1] / "build" / "models" / "mobile_sam.pt"


def sam():
    """The capture step: outline the object inside a box. Loaded on first use."""
    from PIL import Image
    from ultralytics import SAM
    import numpy as np

    SAM_WEIGHTS.parent.mkdir(parents=True, exist_ok=True)
    model = SAM(str(SAM_WEIGHTS))

    def segment(jpeg, box):
        picture = Image.open(io.BytesIO(jpeg)).convert("RGB")
        result = model(picture, bboxes=[box], verbose=False)[0]
        mask = (result.masks.data[0].cpu().numpy() > 0.5).astype(np.uint8) * 255
        out = io.BytesIO()
        Image.fromarray(mask, mode="L").save(out, format="PNG")
        return out.getvalue()

    return segment


def fake_segment(jpeg, box):
    """--fake: a filled box as the 'outline', for tests without a model."""
    from PIL import Image, ImageDraw

    picture = Image.open(io.BytesIO(jpeg))
    mask = Image.new("L", picture.size, 0)
    ImageDraw.Draw(mask).rectangle(box, fill=255)
    out = io.BytesIO()
    mask.save(out, format="PNG")
    return out.getvalue()


def fake(_jpeg):
    return [{"label": "cup", "confidence": 0.9, "box": [0.45, 0.45, 0.55, 0.55]}]


def serve(detect, host, port, make_segment=None):
    segmenters = []  # MobileSAM loads on the first /segment, so /detect starts fast

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            # "Are you there?" (Turn to fit's hub piece is offered only while the server answers)
            if urlparse(self.path).path == "/health":
                self._reply("text/plain", b"ok")
            else:
                self.send_error(404)

        def do_POST(self):
            url = urlparse(self.path)
            jpeg = self.rfile.read(int(self.headers["Content-Length"]))
            if url.path == "/detect":
                self._reply("application/json", json.dumps({"detections": detect(jpeg)}).encode())
            elif url.path == "/segment" and make_segment:
                try:
                    box = [float(v) for v in parse_qs(url.query)["box"][0].split(",")]
                except (KeyError, ValueError):
                    self.send_error(400, "needs ?box=x0,y0,x1,y1 (pixels)")
                    return
                if not segmenters:
                    segmenters.append(make_segment())
                self._reply("image/png", segmenters[0](jpeg, box))
            else:
                self.send_error(404)

        def _reply(self, kind, body):
            self.send_response(200)
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *_args):
            pass

    server = ThreadingHTTPServer((host, port), Handler)
    print(f"CV server on http://{host}:{server.server_port}/detect"
          + (" and /segment" if make_segment else ""), flush=True)
    if host == "0.0.0.0":
        print(f"On the headset, Turn to fit setup → Server: type {lan_address()}", flush=True)
    server.serve_forever()


def lan_address():
    """This laptop's address on the Wi-Fi (what the headset types in Turn to fit's setup)."""
    import socket
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect(("10.255.255.255", 1))  # no packet is sent: it only picks the outgoing interface
        return probe.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        probe.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--host", default="127.0.0.1", help="0.0.0.0 to serve a headset over Wi-Fi")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--model", default=MODEL)
    parser.add_argument("--fake", action="store_true")
    args = parser.parse_args()
    serve(fake if args.fake else yolo(args.model), args.host, args.port,
          (lambda: fake_segment) if args.fake else sam)


if __name__ == "__main__":
    main()
