#!/usr/bin/env python3
"""
Mock/Simulator test runner - Uses expected outputs as test data
Useful for testing the testing infrastructure without Fusion 360
"""

import shutil
from pathlib import Path
from typing import Dict, Tuple


def discover_expected_outputs(expected_dir: Path) -> Dict[str, Path]:
    """Discover all NC files in expected output directories"""
    outputs = {}
    
    for machine_type_dir in expected_dir.iterdir():
        if not machine_type_dir.is_dir():
            continue
        
        for post_dir in machine_type_dir.iterdir():
            if not post_dir.is_dir():
                continue
            
            for nc_file in post_dir.glob("*.nc"):
                # Create standardized output name
                output_name = f"{post_dir.name}_{machine_type_dir.name}_{nc_file.stem}"
                outputs[output_name] = nc_file
    
    return outputs


def populate_outputs(test_dir: Path, mode: str = "copy") -> Tuple[int, Dict]:
    """
    Populate output directory with test data
    
    Args:
        test_dir: Path to tests directory
        mode: "copy" (default) or "link" (creates symlinks instead)
    
    Returns:
        Tuple of (count, mapping)
    """
    expected_dir = test_dir / "expected"
    output_dir = test_dir / "output"
    
    output_dir.mkdir(exist_ok=True)
    
    if not expected_dir.exists():
        print(f"Expected directory not found: {expected_dir}")
        return 0, {}
    
    expected_outputs = discover_expected_outputs(expected_dir)
    
    if not expected_outputs:
        print("No expected outputs found")
        return 0, {}
    
    print(f"\nPopulating output directory with {len(expected_outputs)} test file(s)...\n")
    
    mapping = {}
    created = 0
    
    for output_name, source_file in sorted(expected_outputs.items()):
        dest_file = output_dir / f"{output_name}.nc"
        
        try:
            if mode == "link":
                # Remove existing symlink if present
                if dest_file.exists() or dest_file.is_symlink():
                    dest_file.unlink()
                # Create symlink
                dest_file.symlink_to(source_file)
                print(f"→ {output_name:50s} (linked)")
            else:
                # Copy file
                shutil.copy2(source_file, dest_file)
                print(f"+ {output_name:50s} (copied)")
            
            mapping[output_name] = str(dest_file)
            created += 1
        except Exception as e:
            print(f"✗ {output_name:50s} - ERROR: {e}")
    
    print(f"\n✓ Created {created} test output file(s)")
    return created, mapping


def show_test_files(test_dir: Path):
    """Show what test files are available"""
    expected_dir = test_dir / "expected"
    
    if not expected_dir.exists():
        print("No expected outputs found")
        return
    
    print("\n" + "="*70)
    print("Available Test Files in Expected Outputs")
    print("="*70)
    
    by_type = {}
    total = 0
    
    for machine_type_dir in sorted(expected_dir.iterdir()):
        if not machine_type_dir.is_dir():
            continue
        
        machine_type = machine_type_dir.name
        by_type[machine_type] = {}
        
        for post_dir in sorted(machine_type_dir.iterdir()):
            if not post_dir.is_dir():
                continue
            
            nc_files = list(post_dir.glob("*.nc"))
            if nc_files:
                by_type[machine_type][post_dir.name] = len(nc_files)
                total += len(nc_files)
    
    for machine_type in sorted(by_type.keys()):
        posts = by_type[machine_type]
        print(f"\n{machine_type.upper()} ({sum(posts.values())} files)")
        for post_name in sorted(posts.keys()):
            count = posts[post_name]
            print(f"  - {post_name} ({count} file)")
    
    print(f"\nTotal available test files: {total}")


def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Populate output directory with test data from expected outputs'
    )
    parser.add_argument(
        '--clear', '-c',
        action='store_true',
        help='Clear output directory first'
    )
    parser.add_argument(
        '--list', '-l',
        action='store_true',
        help='List available test files'
    )
    parser.add_argument(
        '--link',
        action='store_true',
        help='Create symlinks instead of copying files'
    )
    
    args = parser.parse_args()
    
    script_dir = Path(__file__).parent
    output_dir = script_dir / "output"
    
    # Show available files
    show_test_files(script_dir)
    
    if args.list:
        return
    
    # Clear output directory if requested
    if args.clear and output_dir.exists():
        print(f"\nClearing output directory...")
        shutil.rmtree(output_dir)
        output_dir.mkdir()
    
    # Populate outputs
    mode = "link" if args.link else "copy"
    count, mapping = populate_outputs(script_dir, mode=mode)
    
    if count > 0:
        print("\n" + "="*70)
        print("✓ Ready to test!")
        print("="*70)
        print("\nRun tests with:")
        print("  python quick_test.py")
        print("  python baseline_manager.py --establish")
        print("  python baseline_manager.py --compare")


if __name__ == "__main__":
    main()
