"""
VS Code-friendly converter from raycloudtools `cloud_trees_info.txt` to a
TreeQSM/rTwig-like QSM CSV.

How to use in Visual Studio Code
--------------------------------
1. Put this Python file in the same folder as `cloud_trees_info.txt`, or edit
   INPUT_FILE below to point to the file.
2. Edit the USER SETTINGS block below.
3. Press the VS Code Run button: "Run Python File".

No command-line arguments are needed.

Input format
------------
`cloud_trees_info.txt` has one tree per line: tree-level attributes first,
then repeated per-node fields:
x,y,z,radius,parent_id,section_id,volume,diameter,length,strength,
min_strength,dominance,angle,children

Conversion logic
----------------
Every node with parent_id >= 0 becomes one cylinder from its parent node to
itself. The first/root node's `section_id` is treated as the tree id.

Notes
-----
Some TreeQSM/rTwig columns cannot be reproduced exactly from RCT data
(e.g. `mad`, `SurfCov`, `added`, `modified`). They are filled from the
closest RCT attributes where possible or with safe defaults. Geometry,
radius, parent-child topology, branch IDs and TreeQSM-like columns are
preserved as closely as possible.
"""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Literal

import numpy as np
import pandas as pd


TREE_META_COLS = [
    "height", "crown_radius", "dimension", "monocotal",
    "DBH", "bend", "branch_slope",
]

RCT_NODE_COLS = [
    "x", "y", "z", "radius", "parent_id", "section_id", "volume",
    "diameter", "length", "strength", "min_strength", "dominance",
    "angle", "children",
]

TREEQSM_COLS = [
    "length",
    "start.x", "start.y", "start.z",
    "axis.x", "axis.y", "axis.z",
    "end.x", "end.y", "end.z",
    "added",
    "PositionInBranch",
    "segment",
    "parentSegment",
    "mad",
    "SurfCov",
    "UnmodRadius",
    "OldRadius",
    "growthLength",
    "branch",
    "branch_alt",
    "parent",
    "extension",
    "totalChildren",
    "BranchOrder",
    "reverseBranchOrder",
    "index",
    "distanceFromBase",
    "distanceToTwig",
    "reversePipeAreaBranchorder",
    "reversePipeRadiusBranchorder",
    "vesselVolume",
    "radius",
    "modified",
]


@dataclass
class RctTree:
    """One tree row from `cloud_trees_info.txt`."""

    tree_id: int
    meta: pd.Series
    nodes: pd.DataFrame


def _split_header(header_line: str) -> tuple[list[str], list[str]]:
    cols = [c.strip() for c in header_line.strip().split(",") if c.strip()]
    try:
        first_node_col = cols.index("x")
    except ValueError as exc:
        raise ValueError("Could not find the first per-node column 'x' in the header.") from exc
    meta_cols = cols[:first_node_col]
    node_cols = cols[first_node_col:]
    if node_cols[:4] != ["x", "y", "z", "radius"]:
        raise ValueError(f"Unexpected per-node columns: {node_cols}")
    return meta_cols, node_cols


def iter_rct_trees(path: str | Path) -> Iterable[RctTree]:
    """
    Yield trees from a raycloudtools tree text file.

    The first non-comment line is expected to be the header. Each following
    line is parsed as one tree.
    """
    path = Path(path)
    with path.open("r", encoding="utf-8") as f:
        lines = f.readlines()

    header_idx = None
    for i, line in enumerate(lines):
        if line.lstrip().startswith("#") or not line.strip():
            continue
        header_idx = i
        break
    if header_idx is None:
        raise ValueError(f"No header found in {path}")

    meta_cols, node_cols = _split_header(lines[header_idx])
    n_meta = len(meta_cols)
    n_node = len(node_cols)

    for line_no, line in enumerate(lines[header_idx + 1 :], start=header_idx + 2):
        if not line.strip():
            continue
        values = np.fromstring(line, sep=",")
        if values.size < n_meta + n_node:
            raise ValueError(f"Line {line_no} is too short to contain one tree.")
        node_values = values[n_meta:]
        if node_values.size % n_node != 0:
            raise ValueError(
                f"Line {line_no}: {node_values.size} node values are not divisible by "
                f"{n_node} node columns."
            )

        meta = pd.Series(values[:n_meta], index=meta_cols)
        nodes = pd.DataFrame(node_values.reshape(-1, n_node), columns=node_cols)
        nodes["parent_id"] = nodes["parent_id"].round().astype(int)
        nodes["section_id"] = nodes["section_id"].round().astype(int)
        nodes["children"] = nodes["children"].round().astype(int)

        # In the RCT export, the first/root node's section_id is the exported tree id.
        root_rows = nodes.index[nodes["parent_id"] < 0].tolist()
        root_idx = root_rows[0] if root_rows else int(nodes.index[0])
        tree_id = int(nodes.loc[root_idx, "section_id"])
        yield RctTree(tree_id=tree_id, meta=meta, nodes=nodes)


def read_rct_tree(path: str | Path, tree_id: int | None = None, tree_index: int | None = None) -> RctTree:
    """
    Read one tree selected by RCT tree id or zero-based row index.
    """
    for idx, tree in enumerate(iter_rct_trees(path)):
        if tree_id is not None and tree.tree_id == tree_id:
            return tree
        if tree_index is not None and idx == tree_index:
            return tree
    selector = f"tree_id={tree_id}" if tree_id is not None else f"tree_index={tree_index}"
    raise KeyError(f"No tree found for {selector}")


def list_trees(path: str | Path) -> pd.DataFrame:
    """
    Return a compact inventory of trees in an RCT tree file.
    """
    rows: list[dict] = []
    for idx, tree in enumerate(iter_rct_trees(path)):
        nodes = tree.nodes
        rows.append(
            {
                "tree_index": idx,
                "tree_id": tree.tree_id,
                "nodes": len(nodes),
                "cylinders": int((nodes["parent_id"] >= 0).sum()),
                "height_attr": float(tree.meta.get("height", np.nan)),
                "dbh_attr": float(tree.meta.get("DBH", np.nan)),
                "x_min": float(nodes["x"].min()),
                "x_max": float(nodes["x"].max()),
                "y_min": float(nodes["y"].min()),
                "y_max": float(nodes["y"].max()),
                "z_min": float(nodes["z"].min()),
                "z_max": float(nodes["z"].max()),
            }
        )
    return pd.DataFrame(rows)


def _children_from_parents(parents: np.ndarray) -> list[list[int]]:
    n = len(parents)
    children: list[list[int]] = [[] for _ in range(n)]
    for child, parent in enumerate(parents):
        if 0 <= parent < n:
            children[parent].append(child)
    return children


def _subtree_node_path_lengths(nodes: pd.DataFrame, children: list[list[int]]) -> tuple[np.ndarray, np.ndarray]:
    """Maximum path length from each node to a descendant tip and the selected main child."""
    xyz = nodes[["x", "y", "z"]].to_numpy(float)
    n = len(nodes)
    max_path = np.zeros(n, dtype=float)
    main_child = np.full(n, -1, dtype=int)

    for i in range(n - 1, -1, -1):
        if not children[i]:
            continue
        best_score = None
        best_child = -1
        best_path = 0.0
        for child in children[i]:
            d = float(np.linalg.norm(xyz[child] - xyz[i]))
            p = d + max_path[child]
            # Prefer larger radius as the trunk/main continuation, then longer path.
            score = (float(nodes.at[child, "radius"]), p)
            if best_score is None or score > best_score:
                best_score = score
                best_child = child
                best_path = p
        main_child[i] = best_child
        max_path[i] = best_path
    return max_path, main_child


def rct_tree_to_treeqsm_table(
    tree: RctTree,
    *,
    radius_source: Literal["child", "parent", "mean"] = "child",
    segment_source: Literal["branch", "rct_section_id"] = "branch",
    origin: Literal["none", "root", "min", "center"] = "none",
    modified_default: int = 0,
    added_default: int = 0,
) -> pd.DataFrame:
    """
    Convert one RCT tree to a TreeQSM/rTwig-like cylinder table.

    Parameters
    ----------
    radius_source:
        Which node radius to use for each cylinder: child node, parent node,
        or the mean of both.
    segment_source:
        Use computed branch id as `segment`, or preserve RCT `section_id`.
    origin:
        Optional coordinate normalization before writing: none, root, minimum xyz,
        or bounding-box center. Default preserves RCT coordinates.
    modified_default, added_default:
        Fill values for rTwig/TreeQSM flags that are not available in RCT data.
    """
    nodes = tree.nodes.reset_index(drop=True).copy()
    if nodes.empty:
        return pd.DataFrame(columns=TREEQSM_COLS)

    xyz = nodes[["x", "y", "z"]].to_numpy(float)
    if origin == "root":
        root_idx = int(np.flatnonzero(nodes["parent_id"].to_numpy(int) < 0)[0])
        xyz = xyz - xyz[root_idx]
    elif origin == "min":
        xyz = xyz - xyz.min(axis=0)
    elif origin == "center":
        xyz = xyz - (xyz.min(axis=0) + xyz.max(axis=0)) / 2.0
    elif origin != "none":
        raise ValueError(f"Unknown origin mode: {origin}")

    parents = nodes["parent_id"].to_numpy(int)
    children = _children_from_parents(parents)
    _node_max_path, main_child = _subtree_node_path_lengths(nodes.assign(x=xyz[:, 0], y=xyz[:, 1], z=xyz[:, 2]), children)

    cyl_nodes = [i for i, p in enumerate(parents) if 0 <= p < len(nodes)]
    node_to_cyl = {node_i: cyl_id for cyl_id, node_i in enumerate(cyl_nodes, start=1)}
    n_cyl = len(cyl_nodes)
    if n_cyl == 0:
        return pd.DataFrame(columns=TREEQSM_COLS)

    # Geometry and direct topology.
    start = np.zeros((n_cyl, 3), dtype=float)
    end = np.zeros((n_cyl, 3), dtype=float)
    axis = np.zeros((n_cyl, 3), dtype=float)
    length = np.zeros(n_cyl, dtype=float)
    parent_cyl = np.zeros(n_cyl, dtype=int)
    child_cyls: list[list[int]] = [[] for _ in range(n_cyl + 1)]  # 1-based id; 0 unused.

    for row0, node_i in enumerate(cyl_nodes):
        p = parents[node_i]
        start[row0] = xyz[p]
        end[row0] = xyz[node_i]
        vec = end[row0] - start[row0]
        length[row0] = float(np.linalg.norm(vec))
        if length[row0] > 0:
            axis[row0] = vec / length[row0]
        else:
            axis[row0] = [0.0, 0.0, 1.0]
        parent_cyl[row0] = node_to_cyl.get(p, 0)

    for row0, node_i in enumerate(cyl_nodes):
        cid = row0 + 1
        for child_node in children[node_i]:
            child_cid = node_to_cyl.get(child_node)
            if child_cid is not None:
                child_cyls[cid].append(child_cid)

    total_children = np.array([len(child_cyls[cid]) for cid in range(1, n_cyl + 1)], dtype=int)

    # Radius.
    node_radius = nodes["radius"].to_numpy(float)
    radius = np.zeros(n_cyl, dtype=float)
    for row0, node_i in enumerate(cyl_nodes):
        p = parents[node_i]
        if radius_source == "child":
            radius[row0] = node_radius[node_i]
        elif radius_source == "parent":
            radius[row0] = node_radius[p]
        elif radius_source == "mean":
            radius[row0] = 0.5 * (node_radius[p] + node_radius[node_i])
        else:
            raise ValueError(f"Unknown radius_source: {radius_source}")

    # Bottom-up descendant metrics.
    growth_length = length.copy()
    distance_to_twig = length.copy()
    terminal_count = np.ones(n_cyl, dtype=int)
    reverse_branch_order = np.ones(n_cyl, dtype=int)

    for cid in range(n_cyl, 0, -1):
        children_ids = child_cyls[cid]
        row0 = cid - 1
        if children_ids:
            growth_length[row0] = length[row0] + sum(growth_length[ch - 1] for ch in children_ids)
            distance_to_twig[row0] = length[row0] + max(distance_to_twig[ch - 1] for ch in children_ids)
            terminal_count[row0] = sum(terminal_count[ch - 1] for ch in children_ids)
            reverse_branch_order[row0] = 1 + max(reverse_branch_order[ch - 1] for ch in children_ids)

    # Distance from base to cylinder start.
    distance_from_base = np.zeros(n_cyl, dtype=float)
    for cid in range(1, n_cyl + 1):
        pc = parent_cyl[cid - 1]
        if pc > 0:
            distance_from_base[cid - 1] = distance_from_base[pc - 1] + length[pc - 1]

    # Branch assignment.
    branch = np.zeros(n_cyl, dtype=int)
    branch_order = np.zeros(n_cyl, dtype=int)
    pos_in_branch = np.zeros(n_cyl, dtype=int)
    next_branch_id = 0

    root_nodes = [i for i, p in enumerate(parents) if p < 0]
    if not root_nodes:
        root_nodes = [cyl_nodes[0]]

    stack: list[tuple[int, int | None, int, int]] = []
    for root_node in root_nodes:
        for child_node in children[root_node]:
            if child_node in node_to_cyl:
                next_branch_id += 1
                stack.append((child_node, next_branch_id, 0, 1))

    # Fallback for malformed roots.
    for node_i in cyl_nodes:
        cid = node_to_cyl[node_i]
        if branch[cid - 1] == 0 and all(node_i != item[0] for item in stack):
            p = parents[node_i]
            if p < 0 or p not in node_to_cyl:
                next_branch_id += 1
                stack.append((node_i, next_branch_id, 0, 1))

    while stack:
        node_i, br, order, pos = stack.pop()
        cid = node_to_cyl[node_i]
        if branch[cid - 1] != 0:
            continue

        branch[cid - 1] = br
        branch_order[cid - 1] = order
        pos_in_branch[cid - 1] = pos

        child_nodes = [c for c in children[node_i] if c in node_to_cyl]
        if not child_nodes:
            continue

        cont = int(main_child[node_i]) if main_child[node_i] in child_nodes else child_nodes[0]
        # Push side branches first, continuation last, so continuation is processed next.
        for c in child_nodes:
            if c == cont:
                continue
            next_branch_id += 1
            stack.append((c, next_branch_id, order + 1, 1))
        stack.append((cont, br, order, pos + 1))

    # Any still-unassigned cylinders get unique branches.
    for cid in range(1, n_cyl + 1):
        if branch[cid - 1] == 0:
            next_branch_id += 1
            branch[cid - 1] = next_branch_id
            branch_order[cid - 1] = 0
            pos_in_branch[cid - 1] = 1

    if segment_source == "branch":
        segment = branch.copy()
    elif segment_source == "rct_section_id":
        segment = nodes.loc[cyl_nodes, "section_id"].to_numpy(int)
    else:
        raise ValueError(f"Unknown segment_source: {segment_source}")

    parent_segment = np.where(parent_cyl > 0, segment[parent_cyl - 1], 0)

    reverse_pipe_area = terminal_count.astype(float)
    reverse_pipe_radius = np.sqrt(reverse_pipe_area)
    vessel_volume = growth_length * reverse_pipe_radius * radius

    df = pd.DataFrame(
        {
            "length": length,
            "start.x": start[:, 0],
            "start.y": start[:, 1],
            "start.z": start[:, 2],
            "axis.x": axis[:, 0],
            "axis.y": axis[:, 1],
            "axis.z": axis[:, 2],
            "end.x": end[:, 0],
            "end.y": end[:, 1],
            "end.z": end[:, 2],
            "added": int(added_default),
            "PositionInBranch": pos_in_branch,
            "segment": segment,
            "parentSegment": parent_segment,
            # No exact TreeQSM fitting residual exists in RCT data; min_strength is the closest scale.
            "mad": nodes.loc[cyl_nodes, "min_strength"].to_numpy(float),
            # RCT dominance is 0..1 and is a useful proxy for coverage/quality.
            "SurfCov": nodes.loc[cyl_nodes, "dominance"].to_numpy(float),
            "UnmodRadius": radius,
            "OldRadius": radius,
            "growthLength": growth_length,
            "branch": branch,
            "branch_alt": branch_order,
            "parent": parent_cyl,
            # In the uploaded rTwig CSV, extension equals row index for all rows.
            "extension": np.arange(1, n_cyl + 1, dtype=int),
            "totalChildren": total_children,
            "BranchOrder": branch_order,
            "reverseBranchOrder": reverse_branch_order,
            "index": np.arange(1, n_cyl + 1, dtype=int),
            "distanceFromBase": distance_from_base,
            "distanceToTwig": distance_to_twig,
            "reversePipeAreaBranchorder": reverse_pipe_area,
            "reversePipeRadiusBranchorder": reverse_pipe_radius,
            "vesselVolume": vessel_volume,
            "radius": radius,
            "modified": int(modified_default),
        }
    )

    return df[TREEQSM_COLS]


def write_treeqsm_csv(
    df: pd.DataFrame,
    path: str | Path,
    *,
    decimal_comma: bool = True,
    include_index: bool = True,
) -> None:
    """
    Write with the same general style as the uploaded rTwig CSV:
    semicolon separator, decimal comma, and an unnamed 1-based index column.
    """
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)

    out = df.copy()
    # Match R's 1-based row index column.
    out.index = np.arange(1, len(out) + 1)

    # Pandas can write the numeric values in the desired format, but the
    # reference rTwig CSV quotes the header labels and the unnamed row index.
    # We therefore write minimally quoted CSV first, then quote only those cells.
    text = out.to_csv(
        sep=";",
        decimal="," if decimal_comma else ".",
        index=include_index,
        index_label="" if include_index else None,
        quoting=csv.QUOTE_MINIMAL,
        lineterminator="\n",
    )

    if include_index:
        lines = text.splitlines()
        if lines:
            header = lines[0].split(";")
            lines[0] = ";".join(f'"{h}"' for h in header)
            for i in range(1, len(lines)):
                first, sep, rest = lines[i].partition(";")
                lines[i] = f'"{first}"{sep}{rest}'
            text = "\n".join(lines) + "\n"

    path.write_text(text, encoding="utf-8")


def convert_one(
    input_path: str | Path,
    output_path: str | Path,
    *,
    tree_id: int | None = None,
    tree_index: int | None = None,
    radius_source: Literal["child", "parent", "mean"] = "child",
    segment_source: Literal["branch", "rct_section_id"] = "branch",
    origin: Literal["none", "root", "min", "center"] = "none",
    decimal_comma: bool = True,
) -> pd.DataFrame:
    tree = read_rct_tree(input_path, tree_id=tree_id, tree_index=tree_index)
    df = rct_tree_to_treeqsm_table(
        tree,
        radius_source=radius_source,
        segment_source=segment_source,
        origin=origin,
    )
    write_treeqsm_csv(df, output_path, decimal_comma=decimal_comma)
    return df



# =============================================================================
# USER SETTINGS - edit these values, then press Run in VS Code
# =============================================================================

# By default the script expects cloud_trees_info.txt in the same folder as this
# .py file. You can also paste an absolute path, for example:
# INPUT_FILE = Path(r"C:\Users\Miha\Documents\cloud_trees_info.txt")
INPUT_FILE = Path(__file__).resolve().parent / "cloud_trees_info.txt"

# Choose one of: "one", "all", "list"
#   "one"  -> convert a single tree
#   "all"  -> convert every tree into OUT_DIR
#   "list" -> print available tree ids and sizes, without writing QSM files
MODE = "one"

# Used only when MODE = "one".
# Prefer TREE_ID, which is the root node section_id matching your exported tree cloud.
# Set TREE_ID = None and use TREE_INDEX if you want the zero-based line index instead.
TREE_ID = 38
TREE_INDEX = None

# Used only when MODE = "one".
# If OUTPUT_FILE is None, a default name is created automatically.
OUTPUT_FILE = Path(__file__).resolve().parent / "cloud_segmented_38_QSM_from_RCT.csv"

# Used only when MODE = "all".
OUT_DIR = Path(__file__).resolve().parent / "qsm_out"

# Conversion options.
# RADIUS_SOURCE: "child", "parent", or "mean"
RADIUS_SOURCE = "child"

# SEGMENT_SOURCE: "branch" for computed branch ids, or "rct_section_id" to keep RCT section_id.
SEGMENT_SOURCE = "branch"

# ORIGIN: "none", "root", "min", or "center".
# "none" preserves original coordinates.
ORIGIN = "none"

# True matches the uploaded rTwig-style CSV better: semicolon separator + decimal comma.
DECIMAL_COMMA = True


# =============================================================================
# VS Code entry point
# =============================================================================

def run_from_vscode() -> None:
    """Run the conversion using the USER SETTINGS block above."""
    input_path = Path(INPUT_FILE)
    if not input_path.exists():
        raise FileNotFoundError(
            f"Input file not found: {input_path}\n"
            "Put cloud_trees_info.txt next to this script or edit INPUT_FILE."
        )

    mode = str(MODE).lower().strip()

    if mode == "list":
        inventory = list_trees(input_path)
        print(inventory.to_string(index=False))
        return

    if mode == "all":
        out_dir = Path(OUT_DIR)
        out_dir.mkdir(parents=True, exist_ok=True)
        count = 0
        for tree in iter_rct_trees(input_path):
            df = rct_tree_to_treeqsm_table(
                tree,
                radius_source=RADIUS_SOURCE,
                segment_source=SEGMENT_SOURCE,
                origin=ORIGIN,
            )
            out_path = out_dir / f"cloud_segmented_{tree.tree_id}_QSM_from_RCT.csv"
            write_treeqsm_csv(df, out_path, decimal_comma=DECIMAL_COMMA)
            count += 1
            print(f"Wrote {out_path} ({len(df)} cylinders)")
        print(f"Done. Converted {count} trees into: {out_dir}")
        return

    if mode == "one":
        if TREE_ID is None and TREE_INDEX is None:
            raise ValueError("For MODE = 'one', set TREE_ID or TREE_INDEX in USER SETTINGS.")

        if OUTPUT_FILE is None:
            suffix = TREE_ID if TREE_ID is not None else f"idx{TREE_INDEX}"
            output_path = input_path.parent / f"cloud_segmented_{suffix}_QSM_from_RCT.csv"
        else:
            output_path = Path(OUTPUT_FILE)

        df = convert_one(
            input_path,
            output_path,
            tree_id=TREE_ID,
            tree_index=TREE_INDEX,
            radius_source=RADIUS_SOURCE,
            segment_source=SEGMENT_SOURCE,
            origin=ORIGIN,
            decimal_comma=DECIMAL_COMMA,
        )
        print(f"Done. Wrote {output_path} ({len(df)} cylinders)")
        return

    raise ValueError("MODE must be one of: 'one', 'all', or 'list'.")


if __name__ == "__main__":
    run_from_vscode()
