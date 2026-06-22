#!/usr/bin/env python3
"""
VS Code Integration - Compare post processor outputs
Opens files for comparison in VS Code
"""

import sys
import subprocess
from pathlib import Path


def find_baseline_nc(baseline_dir: Path, pattern: str):
    """Find NC file matching pattern in baseline"""
    # Try exact match first
    for nc_file in baseline_dir.glob("*.nc"):
        if pattern in nc_file.stem or nc_file.stem == pattern:
            return nc_file
    return None


def compare_in_vscode(file1: Path, file2: Path):
    """
    Open two files in VS Code diff viewer
    Usage: code --diff file1 file2
    """
    if not file1.exists() or not file2.exists():
        print(f"Error: One or both files not found")
        print(f"  File 1: {file1.exists()} - {file1}")
        print(f"  File 2: {file2.exists()} - {file2}")
        return False
    
    try:
        # Use VS Code's built-in diff viewer
        subprocess.Popen(['code', '--diff', str(file1), str(file2)])
        print(f"✓ Opened diff viewer in VS Code")
        print(f"  Left:  {file1.name}")
        print(f"  Right: {file2.name}")
        return True
    except FileNotFoundError:
        print("Error: VS Code 'code' command not found")
        print("Make sure VS Code is installed and 'code' is in your PATH")
        return False
    except Exception as e:
        print(f"Error opening diff: {e}")
        return False


def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Compare files in VS Code diff viewer'
    )
    parser.add_argument(
        'post_name',
        help='Post processor name or NC file pattern (e.g., "Citizen-L320-VIII")'
    )
    parser.add_argument(
        '--baseline-dir',
        type=Path,
        help='Baseline directory (default: ./baseline)'
    )
    parser.add_argument(
        '--output-dir',
        type=Path,
        help='Output directory (default: ./output)'
    )
    
    args = parser.parse_args()
    
    script_dir = Path(__file__).parent
    baseline_dir = args.baseline_dir or (script_dir / "baseline")
    output_dir = args.output_dir or (script_dir / "output")
    
    # Find baseline file
    baseline_file = find_baseline_nc(baseline_dir, args.post_name)
    if not baseline_file:
        print(f"No baseline file found matching: {args.post_name}")
        print(f"Available baselines:")
        for bf in sorted(baseline_dir.glob("*.nc")):
            print(f"  - {bf.stem}")
        return 1
    
    # Find output file (same name)
    output_file = output_dir / f"{baseline_file.stem}.nc"
    if not output_file.exists():
        print(f"No output file found: {output_file.name}")
        return 1
    
    # Open in diff viewer
    if compare_in_vscode(output_file, baseline_file):
        return 0
    else:
        return 1


if __name__ == "__main__":
    sys.exit(main())
