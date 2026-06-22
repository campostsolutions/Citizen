#!/usr/bin/env python3
"""
Quick Test Runner - Simplified all-in-one test command
Runs comparison without needing separate commands
"""

import sys
from pathlib import Path
from baseline_manager import BaselineManager


def main():
    """
    Quick test - runs baseline comparison with simple output
    Usage: python quick_test.py
    """
    script_dir = Path(__file__).parent
    manager = BaselineManager(str(script_dir))
    
    # Show status
    print("\n" + "="*70)
    print("CITIZEN POST PROCESSOR TEST")
    print("="*70)
    
    manager.show_status()
    
    # Compare with baseline
    print("\n")
    results = manager.compare_with_baseline(verbose=False)
    
    # Summary
    print("\n" + "="*70)
    print("NEXT STEPS")
    print("="*70)
    
    matches = sum(1 for r in results.values() if r.get("status") == "match")
    changes = sum(1 for r in results.values() if r.get("status") == "changed")
    new = sum(1 for r in results.values() if r.get("status") == "new")
    
    if changes == 0 and new == 0:
        print("✓ All tests PASS - outputs match baseline!")
        sys.exit(0)
    
    if new > 0:
        print(f"\n✨ {new} new output file(s) found:")
        for name, result in results.items():
            if result.get("status") == "new":
                print(f"   - {name}")
        print(f"\nTo add to baseline:")
        print(f"   python baseline_manager.py --accept-all")
    
    if changes > 0:
        print(f"\n⚠ {changes} output(s) differ from baseline:")
        for name, result in results.items():
            if result.get("status") == "changed":
                print(f"   - {name} ({result.get('similarity')}% similar)")
        print(f"\nTo accept changes:")
        print(f"   python baseline_manager.py --accept-all")
        print(f"\nOr accept specific file:")
        print(f"   python baseline_manager.py --accept <filename>")
    
    print("\n" + "="*70)
    sys.exit(1 if (changes > 0 or new > 0) else 0)


if __name__ == "__main__":
    main()
