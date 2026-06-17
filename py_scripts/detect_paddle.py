#!/usr/bin/env python3

import argparse
import re
from collections import defaultdict
from difflib import SequenceMatcher
from pathlib import Path

import cv2
from paddleocr import PaddleOCR


def similar(a, b):
    return SequenceMatcher(None, a, b).ratio()


def normalize_text(text):

    text = text.strip()

    text = re.sub(r"[^A-Za-z0-9]", "", text)

    return text.upper()


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

    return sorted(images)[:100]


def preprocess(img):

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    gray = cv2.equalizeHist(gray)

    return gray


def majority_string(strings):

    if not strings:
        return None

    max_len = max(len(s) for s in strings)

    result = []

    for pos in range(max_len):
        votes = defaultdict(int)

        for s in strings:
            if pos < len(s):
                votes[s[pos]] += 1

        if not votes:
            continue

        best = max(votes.items(), key=lambda x: x[1])[0]

        result.append(best)

    return "".join(result)


def detect_project_id(folder):

    images = collect_images(folder)

    print(f"Found {len(images)} images")

    if not images:
        return None

    ocr = PaddleOCR(lang="en")

    candidates = []

    for idx, img_path in enumerate(images, start=1):
        try:
            img = cv2.imread(str(img_path))

            if img is None:
                continue

            img = preprocess(img)

            result = ocr.predict(img)

            import pprint

            print("\n====================")
            print(img_path.name)
            print("====================")

            pprint.pp(result)

            break

            if not result:
                continue

            for line in result:
                if not line:
                    continue

                for item in line:
                    try:
                        text = item[1][0]
                        conf = float(item[1][1])

                    except Exception:
                        continue

                    text = normalize_text(text)

                    if not text:
                        continue

                    if conf < 0.40:
                        continue

                    candidates.append(text)

                    print(
                        f"[{idx:03d}/{len(images)}] "
                        f"{img_path.name} "
                        f"-> {text} "
                        f"(conf={conf:.2f})"
                    )

        except Exception as e:
            print(f"ERROR {img_path}")

            print(e)

    if not candidates:
        return None

    #
    # seskupení podobných textů
    #
    groups = []

    for text in candidates:
        matched = False

        for group in groups:
            representative = group[0]

            if similar(representative, text) > 0.80:
                group.append(text)

                matched = True

                break

        if not matched:
            groups.append([text])

    groups.sort(key=len, reverse=True)

    best_group = groups[0]

    print("\nGroups:")
    print("----------------")

    for group in groups:
        print(f"{group[0]} -> {len(group)} hits")

    if len(best_group) < 3:
        print("\nNo reliable PROJECT_ID found")

        return None

    project_id = majority_string(best_group)

    return project_id


def main():

    parser = argparse.ArgumentParser()

    parser.add_argument("folder", help="Folder with images")

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
