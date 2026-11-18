"""Normalize the five desk props and draw their actual top-view outlines.

Optional authoring dependencies: pip install trimesh pillow numpy
Usage: python tools/prepare_desk_assets.py <folder of original mug/notebook/pencil/headphones/plant.glb>
Sources and licenses: trials/desk/assets/CREDITS.md. Runtime needs no Python.
"""
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import trimesh

OUT = Path(__file__).resolve().parents[1] / "trials/desk/assets"
# Desired longest dimension, rotation about X/Y/Z before centring.
PROPS = {"mug": (0.105, (0, 0, 0)), "notebook": (0.17, (0, -np.pi / 2, 0)),
         "pencil": (0.145, (0, 0, 0)), "headphones": (0.135, (-np.pi / 2, 0, 0)),
         "plant": (0.14, (0, 0, 0))}


def prepare(sources):
    sizes = {}
    for name, (length, angles) in PROPS.items():
        scene = trimesh.load(sources / f"{name}.glb", force="scene", process=False)
        scene.apply_transform(trimesh.transformations.euler_matrix(*angles))
        scene.apply_scale(length / max(scene.extents))
        low, high = scene.bounds
        scene.apply_translation([-((low[0] + high[0]) / 2), -low[1], -((low[2] + high[2]) / 2)])
        # Merge the notebook's many spiral rings by material, retaining the source colours.
        groups = {}
        for node in scene.graph.nodes_geometry:
            transform, geometry = scene.graph[node]
            mesh = scene.geometry[geometry].copy()
            mesh.apply_transform(transform)
            material = mesh.visual.material
            material.metallicFactor = 0.0
            material.roughnessFactor = 0.85
            group = node if name == "notebook" and not str(node).startswith("Torus") else material.name
            groups.setdefault(group, []).append(mesh)
        scene = trimesh.Scene()
        for group, meshes in groups.items():
            scene.add_geometry(trimesh.util.concatenate(meshes), node_name=group, geom_name=group)
        (OUT / f"{name}.glb").write_bytes(scene.export(file_type="glb"))
        size = scene.extents
        sizes[name] = [round(float(s), 6) for s in size]
        # Orthographic projection of the very same meshes, including holes in the cup/earphones.
        width, depth = size[[0, 2]] + 0.016
        pixels = max(32, round(768 * width / max(width, depth)))
        height = max(32, round(768 * depth / max(width, depth)))
        mask = Image.new("L", (pixels, height))
        draw = ImageDraw.Draw(mask)
        for mesh in scene.geometry.values():
            points = mesh.vertices[:, [0, 2]]
            points = (points + np.array([width, depth]) / 2) / [width, depth] * [pixels, height]
            for face in mesh.faces:
                draw.polygon([tuple(p) for p in points[face]], fill=255)
        # A 2.5 mm stroke stays readable on the table; all outlines use the same ink.
        stroke = max(3, round(pixels * 0.0025 / width) | 1)
        outer = mask.filter(ImageFilter.MaxFilter(stroke))
        inner = mask.filter(ImageFilter.MinFilter(stroke))
        alpha = Image.fromarray(np.asarray(outer) - np.asarray(inner))
        ink = Image.new("RGBA", mask.size, (48, 63, 75, 0))
        ink.putalpha(alpha)
        ink.save(OUT / f"{name}_outline.png")
        print(name, sizes[name], "meshes", len(scene.geometry))
    (OUT / "sizes.json").write_text(json.dumps(sizes, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    prepare(Path(sys.argv[1]))
