"""Run Citizen post tests and optionally update expected output baselines.

Usage examples:
  python citizen_test_helper.py --post "Citizen L320-VIII"
  python citizen_test_helper.py --post "Citizen L320-VIII" --update-expected
"""

from __future__ import annotations

import argparse
import difflib
import shutil
import subprocess
import sys
from pathlib import Path

IGNORE_SUFFIXES = {".failed", ".bak", ".log"}
TEXT_COMPARE_SUFFIXES = {".output", ".xml", ".testlog", ".simplelog", ".sim", ".txt"}


def run_citizen_tests(tests_dir: Path, post_name: str) -> int:
    """Run the existing batch runner in non-interactive mode."""
    command = f'run-citizen-tests.bat "{post_name}" nopause'
    print(f"Running: {command}")
    completed = subprocess.run(command, cwd=tests_dir, shell=True)
    return completed.returncode


def copy_expected_for_post(tests_dir: Path, post_name: str) -> int:
    """Copy generated output for one post into expected, across all output groups."""
    post_stem = Path(post_name).stem
    output_root = tests_dir / "output"
    expected_root = tests_dir / "expected"

    if not output_root.exists():
        print(f"Output directory does not exist: {output_root}")
        return 1

    matched_dirs = [
        path for path in output_root.rglob("*") if path.is_dir() and path.name.lower() == post_stem.lower()
    ]

    if not matched_dirs:
        print(f"No output folders found for post: {post_stem}")
        return 1

    copied_files = 0
    for src_dir in matched_dirs:
        rel = src_dir.relative_to(output_root)
        dst_dir = expected_root / rel
        dst_dir.mkdir(parents=True, exist_ok=True)

        print(f"Copying {src_dir} -> {dst_dir}")
        for src_file in src_dir.rglob("*"):
            if not src_file.is_file():
                continue
            if src_file.suffix.lower() in IGNORE_SUFFIXES:
                continue

            dst_file = dst_dir / src_file.relative_to(src_dir)
            dst_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src_file, dst_file)
            copied_files += 1

    print(f"Updated expected output files: {copied_files}")
    return 0


def summarize_differences_for_post(tests_dir: Path, post_name: str) -> None:
    """Print file-level and line-level differences for one post.

    The existing Node test runner reports per-test-case status only. This
    summary helps quantify how many lines changed.
    """
    post_stem = Path(post_name).stem
    output_root = tests_dir / "output"
    expected_root = tests_dir / "expected"

    output_dirs = [
        path for path in output_root.rglob("*") if path.is_dir() and path.name.lower() == post_stem.lower()
    ]
    if not output_dirs:
        print(f"No output folders found for post: {post_stem}")
        return

    files_compared = 0
    files_differ = 0
    files_missing_expected = 0
    inserted_lines = 0
    deleted_lines = 0

    for out_dir in output_dirs:
        rel_dir = out_dir.relative_to(output_root)
        exp_dir = expected_root / rel_dir

        for out_file in out_dir.rglob("*"):
            if not out_file.is_file():
                continue
            if out_file.suffix.lower() in IGNORE_SUFFIXES:
                continue
            if out_file.suffix.lower() not in TEXT_COMPARE_SUFFIXES:
                continue

            exp_file = exp_dir / out_file.relative_to(out_dir)
            if not exp_file.exists():
                files_missing_expected += 1
                continue

            files_compared += 1

            out_lines = out_file.read_text(encoding="utf-8", errors="replace").splitlines()
            exp_lines = exp_file.read_text(encoding="utf-8", errors="replace").splitlines()

            matcher = difflib.SequenceMatcher(a=exp_lines, b=out_lines)
            file_has_diff = False
            for tag, i1, i2, j1, j2 in matcher.get_opcodes():
                if tag == "equal":
                    continue
                file_has_diff = True
                if tag in ("replace", "delete"):
                    deleted_lines += i2 - i1
                if tag in ("replace", "insert"):
                    inserted_lines += j2 - j1

            if file_has_diff:
                files_differ += 1

    print("Detailed difference summary:")
    print(f"  Compared files: {files_compared}")
    print(f"  Files with differences: {files_differ}")
    print(f"  Missing expected files: {files_missing_expected}")
    print(f"  Inserted lines: {inserted_lines}")
    print(f"  Deleted lines: {deleted_lines}")


def should_update_expected(non_interactive_yes: bool) -> bool:
    """Ask whether to update expected outputs, unless forced by flag."""
    if non_interactive_yes:
        return True

    answer = input("Update expected output from latest generated files? [y/N]: ").strip().lower()
    return answer in {"y", "yes"}


def normalize_post_name(post_name: str) -> str:
    """Ensure post name has .cps extension for batch compatibility."""
    if post_name.lower().endswith(".cps"):
        return post_name
    return f"{post_name}.cps"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Citizen post tests and optionally update expected output baselines."
    )
    parser.add_argument(
        "--post",
        default="Citizen L320-VIII",
        help="Post name with or without .cps extension (default: Citizen L320-VIII)",
    )
    parser.add_argument(
        "--update-expected",
        action="store_true",
        help="Automatically update expected output after a failed run.",
    )
    parser.add_argument(
        "--no-rerun",
        action="store_true",
        help="Do not rerun tests after updating expected output.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    tests_dir = Path(__file__).resolve().parent
    post_name = normalize_post_name(args.post)

    print(f"Tests directory: {tests_dir}")
    print(f"Post: {post_name}")

    first_exit = run_citizen_tests(tests_dir, post_name)
    if first_exit == 0:
        print("Tests passed. No expected output update needed.")
        return 0

    print("Tests reported changes or failures.")
    summarize_differences_for_post(tests_dir, post_name)
    if not should_update_expected(args.update_expected):
        return first_exit

    update_exit = copy_expected_for_post(tests_dir, post_name)
    if update_exit != 0:
        return update_exit

    if args.no_rerun:
        return 0

    print("Re-running tests after expected output update...")
    return run_citizen_tests(tests_dir, post_name)


if __name__ == "__main__":
    sys.exit(main())
