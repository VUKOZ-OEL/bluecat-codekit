#!/usr/bin/env python3
"""
rct_auto_tiling -- stitch per-tile RCT terrain meshes into ONE seamless mesh.

RCT `rayextract terrain` grids ground points onto a world-aligned 0.01 m grid
and triangulates; buffered tiles overlap, so concatenating their meshes gives
doubled vertices and duplicated triangles in the shared ring (visible seams).

All tile meshes share the SAME world grid, so stitching is exact:
 1. read every tile mesh's vertices + triangular faces,
 2. weld vertices by grid-snapped (gi,gj) key (z averaged across tiles),
 3. remap faces to welded ids and drop duplicate triangles,
 4. write one binary PLY mesh in RCT's own layout (double xyz + uchar rgba,
    faces = int32 count + 3 x int32).

Ready for `rayextract trees <cloud> <stitched_mesh.ply>` (seamless terrain).
"""
from __future__ import annotations

import argparse
import os
import sys

import numpy as np

MESH_VERT_DT = np.dtype([("x", "<f8"), ("y", "<f8"), ("z", "<f8"), ("rgba", "u1", 4)])


def read_mesh(path: str, cell: float):
    """Read an RCT terrain mesh PLY. Returns (x, y, z float64 arrays,
    faces[n,3] int64 local ids, gi, gj int64 grid indices)."""
    nv = nf = 0
    hdr = 0
    face_count_type = None
    with open(path, "rb") as f:
        while True:
            line = f.readline()
            hdr += len(line)
            s = line.decode(errors="replace").split()
            if not s:
                continue
            if s[0] == "element" and s[1] == "vertex":
                nv = int(s[2])
            elif s[0] == "element" and s[1] == "face":
                nf = int(s[2])
            elif s[0] == "property" and s[1] == "list":
                face_count_type = s[2]
            elif s[0] == "end_header":
                break
    ct = {"uchar": 1, "int": 4, "int32": 4}.get(face_count_type or "uchar", 1)
    expected = hdr + nv * 28 + nf * (ct + 12)
    if os.path.getsize(path) != expected:
        sys.exit(f"{path}: unexpected mesh layout (size mismatch)")
    with open(path, "rb") as f:
        f.seek(hdr)
        v = np.frombuffer(f.read(nv * 28), dtype=MESH_VERT_DT, count=nv)
        raw = np.frombuffer(f.read(nf * (ct + 12)), dtype=np.uint8,
                            count=nf * (ct + 12)).reshape(nf, ct + 12)
    faces = np.frombuffer(raw[:, ct:].tobytes(), dtype="<i4").reshape(nf, 3).astype(np.int64)
    gi = np.floor(v["x"] / cell + 1e-6).astype(np.int64)
    gj = np.floor(v["y"] / cell + 1e-6).astype(np.int64)
    return v["x"].astype(np.float64), v["y"].astype(np.float64), v["z"].astype(np.float64), faces, gi, gj


def main() -> int:
    ap = argparse.ArgumentParser(description="stitch per-tile terrain meshes into one seamless mesh")
    ap.add_argument("--meshes", nargs="+", required=True, help="per-tile *_raycloud_mesh.ply files")
    ap.add_argument("--out", required=True, help="output stitched mesh PLY")
    ap.add_argument("--cell", type=float, default=0.01, help="RCT terrain grid cell (m)")
    args = ap.parse_args()

    keys_parts, z_parts, x_parts, y_parts, face_parts = [], [], [], [], []
    nv_off = 0
    for m in args.meshes:
        x, y, z, faces, gi, gj = read_mesh(m, args.cell)
        if len(z) == 0:
            print(f"  {m}: empty mesh (skipped)")
            continue
        keys_parts.append((gi << np.int64(32)) + (gj + (np.int64(1) << 31)))
        z_parts.append(z)
        x_parts.append(x)
        y_parts.append(y)
        face_parts.append(faces + nv_off)
        nv_off += len(z)
        print(f"  {m}: {len(z):,} verts, {len(faces):,} faces")

    if not z_parts:
        sys.exit("no vertices in any mesh")

    all_keys = np.concatenate(keys_parts)
    all_z = np.concatenate(z_parts)
    all_x = np.concatenate(x_parts)
    all_y = np.concatenate(y_parts)
    all_faces = np.concatenate(face_parts, axis=0)

    # weld: unique grid key -> welded id (xyz averaged where tiles agree)
    uniq_keys, inv = np.unique(all_keys, return_inverse=True)
    n_weld = len(uniq_keys)
    zsum = np.zeros(n_weld, dtype=np.float64)
    xsum = np.zeros(n_weld, dtype=np.float64)
    ysum = np.zeros(n_weld, dtype=np.float64)
    zcnt = np.zeros(n_weld, dtype=np.int64)
    np.add.at(zsum, inv, all_z)
    np.add.at(xsum, inv, all_x)
    np.add.at(ysum, inv, all_y)
    np.add.at(zcnt, inv, 1)
    nrep = np.maximum(zcnt, 1)
    z_weld = zsum / nrep
    X = xsum / nrep
    Y = ysum / nrep
    print(f"welded: {all_keys.size:,} -> {n_weld:,} vertices")

    # remap faces to welded ids, drop duplicate triangles
    wf = inv[all_faces]                       # (nf,3) welded ids
    canon = np.sort(wf, axis=1)
    ckey = np.empty(len(canon), dtype=[("a", "<i8"), ("b", "<i8"), ("c", "<i8")])
    ckey["a"], ckey["b"], ckey["c"] = canon[:, 0], canon[:, 1], canon[:, 2]
    _, first_pos = np.unique(ckey, return_index=True)   # first occurrence per unique triangle
    first_pos.sort()
    # keep only non-degenerate triangles
    tri = wf[first_pos]
    degen = (tri[:, 0] == tri[:, 1]) | (tri[:, 1] == tri[:, 2]) | (tri[:, 0] == tri[:, 2])
    tri = tri[~degen]
    print(f"faces: {len(wf):,} -> {len(tri):,} (unique, non-degenerate)")

    # write RCT-layout PLY
    MESH_HDR = ("ply\nformat binary_little_endian 1.0\n"
                "comment rct_auto_tiling stitched terrain\n"
                "element vertex {nv}\nelement face {nf}\n"
                "property double x\nproperty double y\nproperty double z\n"
                "property uchar red\nproperty uchar green\nproperty uchar blue\nproperty uchar alpha\n"
                "property list int int vertex_indices\nend_header\n")
    with open(args.out, "wb") as f:
        f.write(MESH_HDR.format(nv=n_weld, nf=len(tri)).encode())
        verts = np.zeros(n_weld, dtype=MESH_VERT_DT)
        verts["x"] = X
        verts["y"] = Y
        verts["z"] = z_weld
        verts["rgba"] = (128, 128, 128, 255)
        f.write(verts.tobytes())
        tri32 = tri.astype("<i4")
        counts_col = np.full((len(tri32), 1), 3, dtype="<i4")
        f.write(np.concatenate([counts_col, tri32], axis=1).tobytes())
    print(f"stitched mesh: {n_weld:,} verts, {len(tri):,} faces -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
