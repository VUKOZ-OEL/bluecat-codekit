#!/usr/bin/env python3

import argparse
import re
from collections import Counter
from difflib import SequenceMatcher
from pathlib import Path

import cv2
import easyocr


def similar(a, b):
    return SequenceMatcher(None, a, b).ratio()


def collect_images(folder):

    exts = (
        "*.jpg",
        "*.jpeg",
        "*.png",
        "*.JPG",
        "*.JPEG",
        "*.PNG",
    )

    images = []

    for ext in exts:
        images.extend(Path(folder).rglob(ext))

    return sorted(images)[:8]


def normalize_text(text):

    text = text.strip()

    text = re.sub(r"[^A-Za-z0-9]", "", text)

    return text.upper()


def detect_project_id(folder):

    images = collect_images(folder)

    print(f"Found {len(images)} images")

    if not images:
        return None

    reader = easyocr.Reader(["en"], gpu=False)

    detections = []

    for idx, img_path in enumerate(images, start=1):
        try:
            img = cv2.imread(str(img_path))

            if img is None:
                continue

            h, w = img.shape[:2]
            img_area = h * w

            results = reader.readtext(
                img,
                paragraph=False,
                text_threshold=0.6,
                low_text=0.3,
                link_threshold=0.3,
            )

            for bbox, text, conf in results:
                text = normalize_text(text)

                if not text:
                    continue

                if conf < 0.40:
                    continue

                xs = [p[0] for p in bbox]
                ys = [p[1] for p in bbox]

                box_area = (max(xs) - min(xs)) * (max(ys) - min(ys))

                #
                # Ignoruj extrémně malé detekce
                #
                if box_area < img_area * 0.0005:
                    continue

                #
                # Sloučení podobných OCR výsledků
                #
                canonical = text

                for existing in detections:
                    if similar(existing, text) > 0.90:
                        canonical = existing
                        break

                detections.append(canonical)

                print(
                    f"[{idx:03d}/{len(images)}] "
                    f"{img_path.name} "
                    f"-> {canonical} "
                    f"(conf={conf:.2f})"
                )

        except Exception as e:
            print(f"ERROR: {img_path}")

            print(e)

    if not detections:
        return None

    counter = Counter(detections)

    print("\nDetected values:")
    print("----------------")

    for value, count in counter.most_common():
        print(f"{value}: {count}")

    best_value, best_count = counter.most_common(1)[0]

    print(f"\nBest candidate: {best_value} ({best_count}x)")

    #
    # Aby nevznikl PROJECT_ID
    # z jediné náhodné detekce
    #
    if best_count < 3:
        print("\nCandidate rejected (less than 3 hits)")

        return None

    return best_value


def main():

    parser = argparse.ArgumentParser()

    parser.add_argument("folder", help="Folder containing photos")

    args = parser.parse_args()

    project_id = detect_project_id(args.folder)

    print("\n====================")

    if project_id:
        print(f"PROJECT_ID={project_id}")

    else:
        print("PROJECT_ID=NOT_FOUND")

    print("====================")


if __name__ == "__main__":
    main()
