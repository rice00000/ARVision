"""tools/frames.py: the checks that tell a working Quest camera from a broken one."""

import json
from pathlib import Path
import random
import sys
import tempfile
import unittest

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import frames  # noqa: E402

META = {"size": [160, 120], "fov_y": 64.0}


def picture(tint=(1.0, 1.0, 1.0), level=128, size=(160, 120)):
    """A noisy grey scene, scaled per channel by `tint`."""
    rng = random.Random(1)
    image = Image.new("RGB", size)
    image.putdata([tuple(min(255, int(max(0, level + rng.randint(-min(60, level), min(60, level))) * t)) for t in tint)
                   for _ in range(size[0] * size[1])])
    return image


class Frames(unittest.TestCase):
    def test_a_plain_scene_is_fine(self):
        self.assertEqual(frames.problems(picture(), META), [])

    def test_black_red_and_mislabelled_frames_are_flagged(self):
        self.assertIn("blank or black", frames.problems(picture(level=3), META))
        self.assertTrue(frames.problems(picture(tint=(1.0, 0.45, 0.45)), META)[0].startswith("colour cast"))
        self.assertTrue(any("metadata says" in p for p in frames.problems(picture(size=(120, 160)), META)))
        self.assertTrue(any("field of view" in p for p in frames.problems(picture(), dict(META, fov_y=10.0))))

    def run_of(self, folder, *images):
        for index, image in enumerate(images):
            image.save(folder / f"{index:04d}.jpg")
            (folder / f"{index:04d}.json").write_text(json.dumps(dict(META, origin=[0, 0, 0],
                                                                      basis=[[1, 0, 0], [0, 1, 0], [0, 0, 1]])))

    def test_check_passes_a_good_run_and_fails_a_red_one(self):
        with tempfile.TemporaryDirectory() as good, tempfile.TemporaryDirectory() as red:
            self.run_of(Path(good), picture(), picture())
            self.run_of(Path(red), picture(tint=(1.0, 0.4, 0.4)), picture(tint=(1.0, 0.4, 0.4)))
            self.assertEqual(frames.check(Path(good), fake=True), 0)
            self.assertTrue((Path(good) / "review.html").exists())
            self.assertEqual(frames.check(Path(red), fake=True), 1, "every frame has a cast")


if __name__ == "__main__":
    unittest.main()
