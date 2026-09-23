#!/usr/bin/env python3
"""
rct_auto_tiling — shared helpers (pure stdlib, no third-party deps).

Runs on Windows (local test) AND MetaCentrum (singularity python3). The only
data format touched directly is the RayCloudTools PLY (cloud.ply), which is
binary_little_endian with a simple ASCII header — no numpy/gdal required.
"""
from __future__ import annotations
import json, math, os, struct, sys
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

FMT = struct.Struct("<ddddffffBBBB")  # x y z time | nx ny nz | r g b a  (double x4, float x4, uchar x4)
RECORD = 8*4 + 4*4 + 4*1  # = 52 bytes


@dataclass
class PlyInfo:
    path: str
    n_points: int = 0
    has_color: bool = False
    props: Dict[str, str] = None  # name -> type


def read_ply_header(path: str) -> Tuple[int, int, List[str]]:
    """Return (n_points, header_bytes, property_names_in_order)."""
    names: List[str] = []
    n_points = 0
    header_bytes = 0
    with open(path, "rb") as f:
        while True:
            line = f.readline()
            header_bytes += len(line)
            if not line:
                raise ValueError(f"{path}: no end_header")
            text = line.rstrip(b"\r\n")
            if text.startswith(b"element vertex"):
                n_points = int(text.split()[-1])
            elif text.startswith(b"property "):
                names.append(text.decode().split()[-1])
            elif text.startswith(b"end_header"):
                break
    return n_points, header_bytes, names


def ply_info(path: str) -> PlyInfo:
    n, _hdr, names = read_ply_header(path)
    return PlyInfo(path=path, n_points=n, has_color=("red" in names), props={n: "u" for n in names})


def half_open_extent(min_x: float, max_x: float, min_y: float, max_y: float,
                     origin_x: float, origin_y: float, length: float) -> Tuple[int, int, int, int]:
    """Index range [i0,i1) x [j0,j1) of the nominal tiles covering the bbox.
    Half-open convention: tile(i,j) = [ox+iL, ox+(i+1)L) x [oy+jL, oy+(j+1)L).
    A point exactly on an upper edge belongs to the NEIGHBOUR tile (lower index
    owns the lower/given edge)."""
    i0 = math.floor((min_x - origin_x) / length)
    i1 = math.ceil((max_x - origin_x) / length)
    j0 = math.floor((min_y - origin_y) / length)
    j1 = math.ceil((max_y - origin_y) / length)
    return i0, i1, j0, j1


def tile_extent(i: int, j: int, origin_x: float, origin_y: float, length: float) -> Tuple[float, float, float, float]:
    """Nominal (watertight, half-open) extent of tile (i,j)."""
    return origin_x + i * length, origin_x + (i + 1) * length, origin_y + j * length, origin_y + (j + 1) * length


def point_key(x: float, y: float, z: float, delta: float, delta_h: float) -> Tuple[float, float, float]:
    """Deterministic geometric dedup key in the GLOBAL frame. Two detections of
    the same tree in neighbouring tiles must produce the SAME key; two different
    trees must produce DIFFERENT keys."""
    return (round(x / delta) * delta, round(y / delta) * delta, round(z / delta_h) * delta_h)
