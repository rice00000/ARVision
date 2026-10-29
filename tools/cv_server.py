"""CV server for the Detector module's remote backend.

POST /detect with a JPEG body. Reply:
    {"detections": [{"label": "cup", "confidence": 0.91, "box": [x0, y0, x1, y1]}]}
Box corners run 0..1 from the image's top left; labels are COCO class names.

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


def fake(_jpeg):
    return [{"label": "cup", "confidence": 0.9, "box": [0.45, 0.45, 0.55, 0.55]}]


def serve(detect, host, port):
    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path != "/detect":
                self.send_error(404)
                return
            jpeg = self.rfile.read(int(self.headers["Content-Length"]))
            reply = json.dumps({"detections": detect(jpeg)}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(reply)))
            self.end_headers()
            self.wfile.write(reply)

        def log_message(self, *_args):
            pass

    server = ThreadingHTTPServer((host, port), Handler)
    print(f"CV server on http://{host}:{server.server_port}/detect", flush=True)
    server.serve_forever()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--host", default="127.0.0.1", help="0.0.0.0 to serve a headset over Wi-Fi")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--model", default=MODEL)
    parser.add_argument("--fake", action="store_true")
    args = parser.parse_args()
    serve(fake if args.fake else yolo(args.model), args.host, args.port)


if __name__ == "__main__":
    main()
