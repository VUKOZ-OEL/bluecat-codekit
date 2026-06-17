#!/usr/bin/env python3
"""
Merge RayCloudTools tree segmentation exports from overlapping tiles.

The script reads tile clipping polygons from ``tiles.geojson`` and one
``treeinfo.txt`` file per tile directory, detects duplicate trees in tile
overlap regions, and writes a globally unique tree inventory.

Example
-------
python merge_rct_trees.py --project-dir /path/to/project --output-dir /path/to/output

PowerShell example
------------------
python merge_rct_trees.py `
    --project-dir C:\\path\\to\\project `
    --output-dir C:\\path\\to\\output

Dependencies
------------
pandas, numpy, geopandas, shapely, scipy

Typical project layout
----------------------
project/
  tiles.geojson
  tile_001/treeinfo.txt
  tile_002/treeinfo.txt
  tile_003/treeinfo.txt
"""

from __future__ import annotations

import argparse
import csv
import importlib
import itertools
import json
import logging
import math
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Sequence


LOGGER = logging.getLogger("rct_tile_merger")
REQUIRED_DEPENDENCIES = "pandas, numpy, geopandas, shapely, scipy"


def require_dependency(module_name: str) -> Any:
    """Import a required third-party dependency with a clear operator message."""
    try:
        return importlib.import_module(module_name)
    except ImportError as exc:
        raise RuntimeError(
            f"Missing required Python dependency '{module_name}'. "
            f"Install the required packages for this script: {REQUIRED_DEPENDENCIES}."
        ) from exc


@dataclass(frozen=True)
class MergerConfig:
    """Runtime settings and schema mapping for the merger."""

    project_dir: Path
    output_dir: Path
    tiles_geojson: str = "tiles.geojson"
    treeinfo_filename: str = "treeinfo.txt"
    tile_id_property: str = "tile_id"
    parent_id_column: str = "parent_id"
    x_column: str = "x"
    y_column: str = "y"
    z_column: str = "z"
    height_column: str = "height"
    max_xy_distance: float = 1.5
    max_height_difference: float = 2.0
    max_overlap_order: int = 4


@dataclass
class TreeRecord:
    """One tree row loaded from a tile ``treeinfo.txt`` file."""

    record_id: int
    tile_id: str
    parent_id: str
    x: float
    y: float
    z: float
    height: float
    attributes: dict[str, Any]
    overlap_key: tuple[str, ...] | None = None


@dataclass(frozen=True)
class OverlapRegion:
    """A non-empty geometric intersection for a set of tiles."""

    tile_ids: tuple[str, ...]
    geometry: BaseGeometry


@dataclass(frozen=True)
class MatchResult:
    """Similarity result for a candidate pair of tree records."""

    record_a: int
    record_b: int
    distance_xy: float
    height_difference: float
    position_score: float
    height_score: float
    combined_score: float


@dataclass
class MergeResult:
    """Final merged inventory and QA metadata."""

    representatives: list[TreeRecord]
    original_columns: list[str]
    record_to_representative: dict[int, int]
    representative_global_ids: dict[int, int]
    duplicate_relationships: list[tuple[TreeRecord, TreeRecord]]
    input_trees: int
    overlap_regions: int


class JsonLogFormatter(logging.Formatter):
    """Emit compact JSON log records while preserving useful ``extra`` fields."""

    RESERVED_FIELDS = {
        "args",
        "asctime",
        "created",
        "exc_info",
        "exc_text",
        "filename",
        "funcName",
        "levelname",
        "levelno",
        "lineno",
        "module",
        "msecs",
        "message",
        "msg",
        "name",
        "pathname",
        "process",
        "processName",
        "relativeCreated",
        "stack_info",
        "taskName",
        "thread",
        "threadName",
    }

    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        for key, value in record.__dict__.items():
            if key not in self.RESERVED_FIELDS and not key.startswith("_"):
                payload[key] = value
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False, default=str)


class UnionFind:
    """Disjoint-set data structure for scalable duplicate grouping."""

    def __init__(self, item_ids: Iterable[int]) -> None:
        self.parent: dict[int, int] = {}
        self.rank: dict[int, int] = {}
        for item_id in item_ids:
            self.parent[item_id] = item_id
            self.rank[item_id] = 0

    def find(self, item_id: int) -> int:
        """Return the component root for ``item_id``."""
        parent = self.parent[item_id]
        if parent != item_id:
            self.parent[item_id] = self.find(parent)
        return self.parent[item_id]

    def union(self, left: int, right: int) -> None:
        """Merge the components containing ``left`` and ``right``."""
        root_left = self.find(left)
        root_right = self.find(right)
        if root_left == root_right:
            return

        rank_left = self.rank[root_left]
        rank_right = self.rank[root_right]
        if rank_left < rank_right:
            self.parent[root_left] = root_right
        elif rank_left > rank_right:
            self.parent[root_right] = root_left
        else:
            self.parent[root_right] = root_left
            self.rank[root_left] += 1

    def components(self) -> dict[int, list[int]]:
        """Return all connected components keyed by their representative root."""
        grouped: dict[int, list[int]] = defaultdict(list)
        for item_id in self.parent:
            grouped[self.find(item_id)].append(item_id)
        return dict(grouped)


class TileLoader:
    """Load and validate tile clipping polygons."""

    def __init__(self, config: MergerConfig) -> None:
        self.config = config

    def load(self) -> dict[str, BaseGeometry]:
        """Load ``tile_id -> geometry`` from the configured GeoJSON."""
        gpd = require_dependency("geopandas")
        pd = require_dependency("pandas")

        path = self.config.project_dir / self.config.tiles_geojson
        if not path.exists():
            raise FileNotFoundError(f"Tile GeoJSON not found: {path}")

        LOGGER.info("Loading tile polygons", extra={"path": str(path)})
        try:
            gdf = gpd.read_file(path)
        except Exception as exc:
            raise RuntimeError(f"Could not read tile GeoJSON {path}: {exc}") from exc

        if self.config.tile_id_property not in gdf.columns:
            raise ValueError(
                f"Tile GeoJSON is missing property '{self.config.tile_id_property}'. "
                f"Available columns: {list(gdf.columns)}"
            )

        tiles: dict[str, BaseGeometry] = {}
        for row_index, row in gdf.iterrows():
            tile_id_value = row[self.config.tile_id_property]
            if pd.isna(tile_id_value):
                LOGGER.warning(
                    "Skipping tile feature with missing tile id",
                    extra={"row_index": int(row_index)},
                )
                continue

            tile_id = str(tile_id_value)
            geometry = row.geometry
            if geometry is None or geometry.is_empty:
                LOGGER.warning("Skipping tile with empty geometry", extra={"tile_id": tile_id})
                continue
            if not geometry.is_valid:
                repaired = geometry.buffer(0)
                if repaired.is_empty or not repaired.is_valid:
                    LOGGER.warning(
                        "Skipping tile with invalid geometry that could not be repaired",
                        extra={"tile_id": tile_id},
                    )
                    continue
                LOGGER.warning(
                    "Repaired invalid tile geometry with buffer(0)",
                    extra={"tile_id": tile_id},
                )
                geometry = repaired

            if tile_id in tiles:
                raise ValueError(f"Duplicate tile id in GeoJSON: {tile_id}")
            tiles[tile_id] = geometry

        if not tiles:
            raise ValueError(f"No valid tile polygons were loaded from {path}")

        LOGGER.info("Loaded tile polygons", extra={"tile_count": len(tiles)})
        return tiles


class TreeInfoLoader:
    """Load configurable tree information tables from tile directories."""

    def __init__(self, config: MergerConfig) -> None:
        self.config = config

    def load_all(self, tile_ids: Iterable[str]) -> list[TreeRecord]:
        """Load tree records from every tile directory that exists."""
        records: list[TreeRecord] = []
        next_record_id = 0

        for tile_id in sorted(tile_ids):
            treeinfo_path = self.config.project_dir / tile_id / self.config.treeinfo_filename
            if not treeinfo_path.exists():
                LOGGER.warning(
                    "Skipping tile because treeinfo file is missing",
                    extra={"tile_id": tile_id, "path": str(treeinfo_path)},
                )
                continue

            tile_records = self._load_tile_records(treeinfo_path, tile_id, next_record_id)
            records.extend(tile_records)
            next_record_id += len(tile_records)

        LOGGER.info("Loaded tree records", extra={"tree_count": len(records)})
        return records

    def _load_tile_records(self, path: Path, tile_id: str, first_record_id: int) -> list[TreeRecord]:
        pd = require_dependency("pandas")

        try:
            delimiter = self._detect_delimiter(path)
        except ValueError as exc:
            LOGGER.error(
                "Could not detect treeinfo delimiter",
                extra={"tile_id": tile_id, "path": str(path), "error": str(exc)},
            )
            return []

        LOGGER.info(
            "Loading treeinfo file",
            extra={"tile_id": tile_id, "path": str(path), "delimiter": repr(delimiter)},
        )

        try:
            df = pd.read_csv(path, sep=delimiter, dtype=str, keep_default_na=False)
        except Exception as exc:
            LOGGER.error(
                "Could not read treeinfo file",
                extra={"tile_id": tile_id, "path": str(path), "error": str(exc)},
            )
            return []

        df.columns = [str(column).strip() for column in df.columns]
        missing_columns = self._missing_required_columns(df)
        if missing_columns:
            LOGGER.error(
                "Skipping treeinfo file with missing required columns",
                extra={"tile_id": tile_id, "path": str(path), "missing_columns": missing_columns},
            )
            return []

        records: list[TreeRecord] = []
        for row_number, row in df.iterrows():
            try:
                # Keep the parsed numeric fields canonical while preserving the
                # original row attributes verbatim for the merged output.
                record = TreeRecord(
                    record_id=first_record_id + len(records),
                    tile_id=tile_id,
                    parent_id=str(row[self.config.parent_id_column]),
                    x=self._parse_float(row[self.config.x_column], path, row_number, self.config.x_column),
                    y=self._parse_float(row[self.config.y_column], path, row_number, self.config.y_column),
                    z=self._parse_float(row[self.config.z_column], path, row_number, self.config.z_column),
                    height=self._parse_float(row[self.config.height_column], path, row_number, self.config.height_column),
                    attributes=row.to_dict(),
                )
            except ValueError as exc:
                LOGGER.warning(
                    "Skipping invalid tree row",
                    extra={"tile_id": tile_id, "row_number": int(row_number) + 2, "error": str(exc)},
                )
                continue
            records.append(record)

        LOGGER.info(
            "Loaded treeinfo rows",
            extra={"tile_id": tile_id, "tree_count": len(records), "path": str(path)},
        )
        return records

    def _missing_required_columns(self, df: pd.DataFrame) -> list[str]:
        required_columns = [
            self.config.parent_id_column,
            self.config.x_column,
            self.config.y_column,
            self.config.z_column,
            self.config.height_column,
        ]
        return [column for column in required_columns if column not in df.columns]

    @staticmethod
    def _parse_float(value: Any, path: Path, row_number: int, column: str) -> float:
        try:
            parsed = float(value)
        except (TypeError, ValueError) as exc:
            raise ValueError(
                f"Could not parse numeric column '{column}' in {path.name} row {row_number + 2}: {value!r}"
            ) from exc

        if not math.isfinite(parsed):
            raise ValueError(f"Column '{column}' must be finite in {path.name} row {row_number + 2}")
        return parsed

    @staticmethod
    def _detect_delimiter(path: Path) -> str:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            sample = handle.read(8192)

        if not sample.strip():
            raise ValueError(f"Treeinfo file is empty: {path}")

        try:
            dialect = csv.Sniffer().sniff(sample, delimiters=",;\t")
            return dialect.delimiter
        except csv.Error:
            first_line = sample.splitlines()[0]
            counts = {delimiter: first_line.count(delimiter) for delimiter in [",", ";", "\t"]}
            delimiter, count = max(counts.items(), key=lambda item: item[1])
            if count == 0:
                raise ValueError(f"Could not detect delimiter for treeinfo file: {path}")
            return delimiter


class OverlapAnalyzer:
    """Build tile overlap regions and assign tree membership."""

    def __init__(self, config: MergerConfig) -> None:
        self.config = config

    def build_overlap_regions(self, tiles: dict[str, BaseGeometry]) -> list[OverlapRegion]:
        """Return all non-zero-area intersections up to ``max_overlap_order``."""
        tile_items = sorted(tiles.items())
        regions: list[OverlapRegion] = []

        for order in range(2, min(self.config.max_overlap_order, len(tile_items)) + 1):
            for combination in itertools.combinations(tile_items, order):
                tile_ids = tuple(tile_id for tile_id, _ in combination)
                geometry = combination[0][1]
                for _, next_geometry in combination[1:]:
                    geometry = geometry.intersection(next_geometry)
                    if geometry.is_empty:
                        break

                if geometry.is_empty or geometry.area <= 0:
                    continue

                regions.append(OverlapRegion(tile_ids=tile_ids, geometry=geometry))

        LOGGER.info("Built overlap regions", extra={"overlap_region_count": len(regions)})
        return regions

    def assign_tree_membership(
        self,
        records: list[TreeRecord],
        regions: Sequence[OverlapRegion],
    ) -> dict[tuple[str, ...], list[TreeRecord]]:
        """
        Assign each tree to the most specific overlap region containing its XY point.

        Trees outside all overlap regions are not returned here because they are
        automatically accepted as unique records.
        """
        geometry_module = require_dependency("shapely.geometry")
        prepared_module = require_dependency("shapely.prepared")
        Point = geometry_module.Point
        prep = prepared_module.prep

        prepared_regions = [
            (region.tile_ids, prep(region.geometry), len(region.tile_ids))
            for region in sorted(regions, key=lambda item: len(item.tile_ids), reverse=True)
        ]
        overlap_groups: dict[tuple[str, ...], list[TreeRecord]] = defaultdict(list)

        for record in records:
            point = Point(record.x, record.y)
            for tile_ids, prepared_geometry, _ in prepared_regions:
                if record.tile_id not in tile_ids:
                    continue
                if prepared_geometry.covers(point):
                    record.overlap_key = tile_ids
                    overlap_groups[tile_ids].append(record)
                    break

        LOGGER.info(
            "Assigned overlap memberships",
            extra={
                "overlap_group_count": len(overlap_groups),
                "trees_in_overlap": sum(len(group) for group in overlap_groups.values()),
            },
        )
        return dict(overlap_groups)


class SimilarityScorer:
    """Isolated tree matching criteria for future QSM or crown extensions."""

    def __init__(self, config: MergerConfig) -> None:
        self.config = config

    def score(self, left: TreeRecord, right: TreeRecord, distance_xy: float) -> MatchResult | None:
        """Return a match score when two trees satisfy all configured thresholds."""
        if left.tile_id == right.tile_id:
            return None

        height_difference = abs(left.height - right.height)
        if distance_xy > self.config.max_xy_distance:
            return None
        if height_difference > self.config.max_height_difference:
            return None

        position_score = 1.0 - (distance_xy / self.config.max_xy_distance)
        height_score = 1.0 - (height_difference / self.config.max_height_difference)
        combined_score = (position_score + height_score) / 2.0
        return MatchResult(
            record_a=left.record_id,
            record_b=right.record_id,
            distance_xy=distance_xy,
            height_difference=height_difference,
            position_score=position_score,
            height_score=height_score,
            combined_score=combined_score,
        )


class DuplicateMatcher:
    """Find duplicate candidate pairs using spatial indexing."""

    def __init__(self, config: MergerConfig, scorer: SimilarityScorer | None = None) -> None:
        self.config = config
        self.scorer = scorer or SimilarityScorer(config)

    def find_matches(self, overlap_groups: dict[tuple[str, ...], list[TreeRecord]]) -> list[MatchResult]:
        """Find all duplicate pair matches inside overlap groups."""
        np = require_dependency("numpy")
        spatial_module = require_dependency("scipy.spatial")
        cKDTree = spatial_module.cKDTree

        matches: list[MatchResult] = []
        seen_pairs: set[tuple[int, int]] = set()

        for overlap_key, records in sorted(overlap_groups.items()):
            if len(records) < 2:
                continue

            coordinates = np.array([(record.x, record.y) for record in records], dtype=float)
            tree = cKDTree(coordinates)
            candidate_pairs = tree.query_pairs(r=self.config.max_xy_distance)

            for left_index, right_index in candidate_pairs:
                left = records[left_index]
                right = records[right_index]
                pair_key = tuple(sorted((left.record_id, right.record_id)))
                if pair_key in seen_pairs:
                    continue

                distance_xy = float(np.linalg.norm(coordinates[left_index] - coordinates[right_index]))
                match = self.scorer.score(left, right, distance_xy)
                if match is None:
                    continue

                seen_pairs.add(pair_key)
                matches.append(match)

            LOGGER.info(
                "Matched duplicate candidates in overlap group",
                extra={
                    "overlap_key": ",".join(overlap_key),
                    "tree_count": len(records),
                    "candidate_pair_count": len(candidate_pairs),
                },
            )

        LOGGER.info("Found duplicate matches", extra={"match_count": len(matches)})
        return matches


class TreeMerger:
    """Merge duplicate components and assign global tree identifiers."""

    def __init__(self, tile_geometries: dict[str, BaseGeometry]) -> None:
        self.tile_geometries = tile_geometries

    def merge(
        self,
        records: list[TreeRecord],
        matches: Sequence[MatchResult],
        overlap_region_count: int,
    ) -> MergeResult:
        """Return a deterministic merged inventory from records and pair matches."""
        record_by_id = {record.record_id: record for record in records}
        union_find = UnionFind(record_by_id)
        for match in matches:
            union_find.union(match.record_a, match.record_b)

        representatives: list[TreeRecord] = []
        record_to_representative: dict[int, int] = {}

        for component_ids in union_find.components().values():
            component_records = [record_by_id[record_id] for record_id in component_ids]
            representative = self._select_representative(component_records)
            representatives.append(representative)
            for record in component_records:
                record_to_representative[record.record_id] = representative.record_id

        representatives.sort(key=lambda record: (record.x, record.y, record.tile_id, record.parent_id))
        representative_global_ids = {
            representative.record_id: index
            for index, representative in enumerate(representatives, start=1)
        }

        duplicate_relationships: list[tuple[TreeRecord, TreeRecord]] = []
        for record in records:
            representative_id = record_to_representative[record.record_id]
            if representative_id == record.record_id:
                continue
            duplicate_relationships.append((record_by_id[representative_id], record))

        duplicate_relationships.sort(
            key=lambda pair: (
                representative_global_ids[pair[0].record_id],
                pair[1].tile_id,
                pair[1].parent_id,
            )
        )

        return MergeResult(
            representatives=representatives,
            original_columns=self._collect_original_columns(records),
            record_to_representative=record_to_representative,
            representative_global_ids=representative_global_ids,
            duplicate_relationships=duplicate_relationships,
            input_trees=len(records),
            overlap_regions=overlap_region_count,
        )

    def _select_representative(self, component: Sequence[TreeRecord]) -> TreeRecord:
        """Select one component representative using the required stable priority."""
        return min(
            component,
            key=lambda record: (
                -self._distance_to_tile_boundary(record),
                -record.height,
                record.tile_id,
                str(record.parent_id),
                record.record_id,
            ),
        )

    def _distance_to_tile_boundary(self, record: TreeRecord) -> float:
        geometry_module = require_dependency("shapely.geometry")
        Point = geometry_module.Point

        geometry = self.tile_geometries.get(record.tile_id)
        if geometry is None:
            return 0.0
        return float(Point(record.x, record.y).distance(geometry.boundary))

    @staticmethod
    def _collect_original_columns(records: Sequence[TreeRecord]) -> list[str]:
        columns: list[str] = []
        seen: set[str] = set()
        for record in records:
            for column in record.attributes:
                if column not in seen:
                    seen.add(column)
                    columns.append(column)
        return columns


class OutputWriter:
    """Write merged inventory and QA output files."""

    def __init__(self, config: MergerConfig) -> None:
        self.config = config

    def write(self, result: MergeResult) -> None:
        """Write all configured output files."""
        self.config.output_dir.mkdir(parents=True, exist_ok=True)
        self._write_merged_treeinfo(result)
        self._write_duplicates(result)
        self._write_statistics(result)

    def _write_merged_treeinfo(self, result: MergeResult) -> None:
        pd = require_dependency("pandas")

        rows: list[dict[str, Any]] = []

        for representative in result.representatives:
            row: dict[str, Any] = {
                "global_tree_id": result.representative_global_ids[representative.record_id],
                "tile_id": representative.tile_id,
                "parent_id": representative.parent_id,
            }
            for column in result.original_columns:
                if column in {"global_tree_id", "tile_id"}:
                    continue
                if column == "parent_id":
                    row[column] = representative.parent_id
                else:
                    row[column] = representative.attributes.get(column, "")
            rows.append(row)

        output_path = self.config.output_dir / "merged_treeinfo.csv"
        pd.DataFrame(rows).to_csv(output_path, index=False)
        LOGGER.info("Wrote merged tree inventory", extra={"path": str(output_path), "row_count": len(rows)})

    def _write_duplicates(self, result: MergeResult) -> None:
        pd = require_dependency("pandas")

        columns = [
            "representative_global_id",
            "representative_tile",
            "representative_parent_id",
            "duplicate_tile",
            "duplicate_parent_id",
        ]
        rows = []
        for representative, duplicate in result.duplicate_relationships:
            rows.append(
                {
                    "representative_global_id": result.representative_global_ids[representative.record_id],
                    "representative_tile": representative.tile_id,
                    "representative_parent_id": representative.parent_id,
                    "duplicate_tile": duplicate.tile_id,
                    "duplicate_parent_id": duplicate.parent_id,
                }
            )

        output_path = self.config.output_dir / "duplicates.csv"
        pd.DataFrame(rows, columns=columns).to_csv(output_path, index=False)
        LOGGER.info("Wrote duplicate relationships", extra={"path": str(output_path), "row_count": len(rows)})

    def _write_statistics(self, result: MergeResult) -> None:
        unique_trees = len(result.representatives)
        statistics = {
            "input_trees": result.input_trees,
            "unique_trees": unique_trees,
            "duplicate_trees": result.input_trees - unique_trees,
            "overlap_regions": result.overlap_regions,
        }
        output_path = self.config.output_dir / "merge_statistics.json"
        with output_path.open("w", encoding="utf-8") as handle:
            json.dump(statistics, handle, indent=2)
            handle.write("\n")
        LOGGER.info("Wrote merge statistics", extra={"path": str(output_path), **statistics})


def run_merge(config: MergerConfig) -> MergeResult:
    """Execute the full tile-aware tree merge workflow."""
    tile_loader = TileLoader(config)
    tree_loader = TreeInfoLoader(config)
    overlap_analyzer = OverlapAnalyzer(config)
    duplicate_matcher = DuplicateMatcher(config)

    tiles = tile_loader.load()
    tile_dirs = {path.name for path in config.project_dir.iterdir() if path.is_dir()}
    for tile_id in sorted(tile_dirs - set(tiles)):
        LOGGER.warning("Ignoring tile directory with no matching GeoJSON feature", extra={"tile_id": tile_id})

    records = tree_loader.load_all(tiles.keys())
    if not records:
        raise ValueError("No valid tree records were loaded. Nothing to merge.")

    missing_tile_dirs = sorted(
        tile_id for tile_id in tiles if not (config.project_dir / tile_id).is_dir()
    )
    for tile_id in missing_tile_dirs:
        LOGGER.warning("Tile directory is missing", extra={"tile_id": tile_id})

    overlap_regions = overlap_analyzer.build_overlap_regions(tiles)
    overlap_groups = overlap_analyzer.assign_tree_membership(records, overlap_regions)
    matches = duplicate_matcher.find_matches(overlap_groups)

    merger = TreeMerger(tiles)
    result = merger.merge(records, matches, overlap_region_count=len(overlap_regions))
    OutputWriter(config).write(result)
    return result


def configure_logging(level: str) -> None:
    """Configure structured line-oriented logging."""
    handler = logging.StreamHandler()
    handler.setFormatter(JsonLogFormatter())
    logging.basicConfig(level=getattr(logging, level.upper()), handlers=[handler])


def build_arg_parser() -> argparse.ArgumentParser:
    """Build the command-line interface."""
    parser = argparse.ArgumentParser(
        description="Merge RayCloudTools treeinfo outputs from overlapping tiles.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--project-dir", required=True, type=Path, help="Root directory containing tiles.geojson and tile folders.")
    parser.add_argument("--output-dir", required=True, type=Path, help="Directory for merged_treeinfo.csv and QA outputs.")
    parser.add_argument("--tiles-geojson", default="tiles.geojson", help="GeoJSON filename inside project-dir.")
    parser.add_argument("--treeinfo-filename", default="treeinfo.txt", help="Tree information filename inside each tile directory.")
    parser.add_argument("--tile-id-property", default="tile_id", help="GeoJSON feature property matching tile directory names.")
    parser.add_argument("--parent-id-column", default="parent_id", help="Treeinfo column containing the original RCT tree id.")
    parser.add_argument("--x-column", default="x", help="Treeinfo X coordinate column.")
    parser.add_argument("--y-column", default="y", help="Treeinfo Y coordinate column.")
    parser.add_argument("--z-column", default="z", help="Treeinfo Z coordinate column.")
    parser.add_argument("--height-column", default="height", help="Treeinfo tree height column.")
    parser.add_argument("--max-xy-distance", default=1.5, type=float, help="Maximum XY distance for duplicate matches.")
    parser.add_argument("--max-height-difference", default=2.0, type=float, help="Maximum height difference for duplicate matches.")
    parser.add_argument("--max-overlap-order", default=4, type=int, help="Highest tile-overlap order to evaluate.")
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging verbosity.",
    )
    return parser


def config_from_args(args: argparse.Namespace) -> MergerConfig:
    """Convert parsed CLI arguments to a validated config object."""
    project_dir = args.project_dir.resolve()
    output_dir = args.output_dir.resolve()

    if not project_dir.exists():
        raise FileNotFoundError(f"Project directory does not exist: {project_dir}")
    if not project_dir.is_dir():
        raise NotADirectoryError(f"Project path is not a directory: {project_dir}")
    if args.max_xy_distance <= 0:
        raise ValueError("--max-xy-distance must be greater than zero")
    if args.max_height_difference <= 0:
        raise ValueError("--max-height-difference must be greater than zero")
    if args.max_overlap_order < 2:
        raise ValueError("--max-overlap-order must be at least 2")

    return MergerConfig(
        project_dir=project_dir,
        output_dir=output_dir,
        tiles_geojson=args.tiles_geojson,
        treeinfo_filename=args.treeinfo_filename,
        tile_id_property=args.tile_id_property,
        parent_id_column=args.parent_id_column,
        x_column=args.x_column,
        y_column=args.y_column,
        z_column=args.z_column,
        height_column=args.height_column,
        max_xy_distance=args.max_xy_distance,
        max_height_difference=args.max_height_difference,
        max_overlap_order=args.max_overlap_order,
    )


def main(argv: Sequence[str] | None = None) -> int:
    """CLI entrypoint."""
    parser = build_arg_parser()
    args = parser.parse_args(argv)
    configure_logging(args.log_level)

    try:
        config = config_from_args(args)
        result = run_merge(config)
    except Exception as exc:
        LOGGER.error("Tree merge failed", extra={"error": str(exc)})
        if args.log_level == "DEBUG":
            raise
        return 1

    LOGGER.info(
        "Tree merge complete",
        extra={
            "input_trees": result.input_trees,
            "unique_trees": len(result.representatives),
            "duplicate_trees": result.input_trees - len(result.representatives),
        },
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
