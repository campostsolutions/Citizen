#!/usr/bin/env python3
"""
Baseline Management and Comparison Tool
Manages expected outputs as baselines and tracks changes
"""

import os
import sys
import shutil
import difflib
from pathlib import Path
from typing import Dict, Tuple
import argparse
import json


class BaselineManager:
    def __init__(self, test_dir: str):
        self.test_dir = Path(test_dir)
        self.output_dir = self.test_dir / "output"
        self.expected_dir = self.test_dir / "expected"
        self.baseline_dir = self.test_dir / "baseline"
        self.baseline_metadata = self.test_dir / "baseline_metadata.json"
        
        # Ensure baseline directory exists
        self.baseline_dir.mkdir(exist_ok=True)
    
    def load_metadata(self) -> Dict:
        """Load baseline metadata"""
        if self.baseline_metadata.exists():
            with open(self.baseline_metadata, 'r') as f:
                return json.load(f)
        return {}
    
    def save_metadata(self, metadata: Dict):
        """Save baseline metadata"""
        with open(self.baseline_metadata, 'w') as f:
            json.dump(metadata, f, indent=2)
    
    def normalize_nc_code(self, content: str) -> str:
        """Normalize NC code for comparison"""
        lines = []
        for line in content.split('\n'):
            # Remove comments
            if '(' in line:
                line = line[:line.index('(')]
            line = line.strip()
            if line:
                line = ' '.join(line.split())
                lines.append(line)
        return '\n'.join(lines)
    
    def calculate_hash(self, content: str) -> str:
        """Calculate hash of normalized content"""
        import hashlib
        normalized = self.normalize_nc_code(content)
        return hashlib.md5(normalized.encode()).hexdigest()
    
    def find_generated_outputs(self) -> Dict[str, Path]:
        """Find all generated NC files"""
        if not self.output_dir.exists():
            print(f"Output directory not found: {self.output_dir}")
            return {}
        
        outputs = {}
        for nc_file in sorted(self.output_dir.glob("**/*.nc")):
            outputs[nc_file.stem] = nc_file
        
        return outputs
    
    def establish_baseline(self, force=False) -> Dict:
        """Establish baseline from current outputs"""
        print("\n" + "="*70)
        print("Establishing Baseline")
        print("="*70)
        
        generated = self.find_generated_outputs()
        metadata = self.load_metadata()
        established = 0
        updated = 0
        skipped = 0
        
        if not generated:
            print("No generated outputs found in 'output' directory")
            return {"established": 0, "updated": 0, "skipped": 0}
        
        print(f"\nFound {len(generated)} generated outputs\n")
        
        for output_name, gen_file in generated.items():
            baseline_file = self.baseline_dir / f"{output_name}.nc"
            
            # Read generated content
            with open(gen_file, 'r', encoding='utf-8', errors='ignore') as f:
                gen_content = f.read()
            
            gen_hash = self.calculate_hash(gen_content)
            
            # Check if baseline exists
            if baseline_file.exists() and not force:
                with open(baseline_file, 'r', encoding='utf-8', errors='ignore') as f:
                    baseline_content = f.read()
                
                baseline_hash = self.calculate_hash(baseline_content)
                
                if gen_hash == baseline_hash:
                    print(f"✓ {output_name:50s} - Already matches baseline")
                    skipped += 1
                else:
                    print(f"⚠ {output_name:50s} - Different from baseline")
                    print(f"  Use: python baseline_manager.py --accept {output_name}")
                    print(f"       to update baseline with new version")
                    skipped += 1
            else:
                # Establish or update baseline
                shutil.copy2(gen_file, baseline_file)
                metadata[output_name] = {
                    "hash": gen_hash,
                    "source": str(gen_file),
                    "size": gen_file.stat().st_size
                }
                
                if force:
                    print(f"→ {output_name:50s} - UPDATED baseline")
                    updated += 1
                else:
                    print(f"+ {output_name:50s} - ESTABLISHED baseline")
                    established += 1
        
        self.save_metadata(metadata)
        
        print("\n" + "="*70)
        print("Baseline Summary")
        print("="*70)
        print(f"✓ Established: {established}")
        print(f"→ Updated:     {updated}")
        print(f"⚠ Unchanged:   {skipped}")
        print(f"Total:       {len(generated)}")
        
        return {"established": established, "updated": updated, "skipped": skipped}
    
    def compare_with_baseline(self, verbose=False) -> Dict:
        """Compare generated outputs with baseline"""
        print("\n" + "="*70)
        print("Comparing Against Baseline")
        print("="*70)
        
        generated = self.find_generated_outputs()
        metadata = self.load_metadata()
        results = {}
        matches = 0
        changes = 0
        new_files = 0
        
        if not generated:
            print("No generated outputs found in 'output' directory")
            return results
        
        print(f"\nFound {len(generated)} generated outputs\n")
        
        for output_name, gen_file in generated.items():
            baseline_file = self.baseline_dir / f"{output_name}.nc"
            
            # Read generated content
            with open(gen_file, 'r', encoding='utf-8', errors='ignore') as f:
                gen_content = f.read()
            
            gen_hash = self.calculate_hash(gen_content)
            
            # Check if baseline exists
            if not baseline_file.exists():
                print(f"✨ {output_name:50s} - NEW (not in baseline)")
                print(f"   Use: python baseline_manager.py --accept {output_name}")
                print(f"        to add to baseline")
                new_files += 1
                results[output_name] = {
                    "status": "new",
                    "message": "New file, not in baseline"
                }
            else:
                with open(baseline_file, 'r', encoding='utf-8', errors='ignore') as f:
                    baseline_content = f.read()
                
                baseline_hash = self.calculate_hash(baseline_content)
                
                if gen_hash == baseline_hash:
                    print(f"✓ {output_name:50s} - MATCH")
                    matches += 1
                    results[output_name] = {"status": "match"}
                else:
                    # Calculate difference
                    gen_lines = gen_content.split('\n')
                    baseline_lines = baseline_content.split('\n')
                    similarity = difflib.SequenceMatcher(None, baseline_lines, gen_lines).ratio()
                    
                    print(f"⚠ {output_name:50s} - CHANGED ({similarity*100:.1f}% similar)")
                    print(f"  Generated: {len(gen_lines)} lines, {gen_file.stat().st_size} bytes")
                    print(f"  Baseline:  {len(baseline_lines)} lines, {baseline_file.stat().st_size} bytes")
                    
                    if verbose:
                        # Show first few differences
                        diff = list(difflib.unified_diff(
                            baseline_lines[:10], 
                            gen_lines[:10], 
                            lineterm='',
                            fromfile='baseline',
                            tofile='generated'
                        ))
                        if diff:
                            print("  Diff preview:")
                            for line in diff[:5]:
                                print(f"    {line}")
                    
                    print(f"  Use: python baseline_manager.py --accept {output_name}")
                    print(f"       to update baseline")
                    
                    changes += 1
                    results[output_name] = {
                        "status": "changed",
                        "similarity": round(similarity * 100, 1),
                        "gen_lines": len(gen_lines),
                        "baseline_lines": len(baseline_lines),
                        "gen_size": gen_file.stat().st_size,
                        "baseline_size": baseline_file.stat().st_size
                    }
        
        print("\n" + "="*70)
        print("Comparison Summary")
        print("="*70)
        print(f"✓ Match:     {matches}")
        print(f"⚠ Changed:   {changes}")
        print(f"✨ New:      {new_files}")
        print(f"Total:     {len(generated)}")
        
        if changes > 0 or new_files > 0:
            print("\n⚠ Found differences. Review changes and update baseline if needed.")
        else:
            print("\n✓ All outputs match baseline!")
        
        return results
    
    def accept_changes(self, file_pattern=None, all_files=False) -> int:
        """Accept generated outputs and update baseline"""
        generated = self.find_generated_outputs()
        metadata = self.load_metadata()
        updated = 0
        
        if all_files:
            targets = list(generated.items())
        elif file_pattern:
            targets = [(name, path) for name, path in generated.items() 
                      if file_pattern.lower() in name.lower()]
        else:
            targets = []
        
        if not targets:
            print(f"No files found matching pattern: {file_pattern}")
            return 0
        
        print(f"\nUpdating baseline for {len(targets)} file(s)...\n")
        
        for output_name, gen_file in targets:
            baseline_file = self.baseline_dir / f"{output_name}.nc"
            
            # Read generated content
            with open(gen_file, 'r', encoding='utf-8', errors='ignore') as f:
                gen_content = f.read()
            
            gen_hash = self.calculate_hash(gen_content)
            
            # Update baseline
            shutil.copy2(gen_file, baseline_file)
            metadata[output_name] = {
                "hash": gen_hash,
                "source": str(gen_file),
                "size": gen_file.stat().st_size
            }
            
            print(f"→ {output_name:50s} - UPDATED")
            updated += 1
        
        self.save_metadata(metadata)
        
        print(f"\n✓ Updated {updated} baseline file(s)")
        return updated
    
    def show_status(self) -> Dict:
        """Show current status of baselines"""
        print("\n" + "="*70)
        print("Baseline Status")
        print("="*70)
        
        metadata = self.load_metadata()
        baseline_files = list(self.baseline_dir.glob("*.nc"))
        
        print(f"\nBaseline directory: {self.baseline_dir}")
        print(f"Files in baseline: {len(baseline_files)}")
        
        if baseline_files:
            print("\nBaseline files:")
            for bf in sorted(baseline_files):
                print(f"  - {bf.stem}")
        
        if metadata:
            print(f"\nTracked files: {len(metadata)}")
        
        return {
            "baseline_count": len(baseline_files),
            "tracked_count": len(metadata)
        }


def main():
    parser = argparse.ArgumentParser(
        description='Manage post processor output baselines'
    )
    parser.add_argument(
        '--establish', '-e',
        action='store_true',
        help='Establish baseline from current outputs'
    )
    parser.add_argument(
        '--force', '-f',
        action='store_true',
        help='Force update baseline (use with --establish)'
    )
    parser.add_argument(
        '--compare', '-c',
        action='store_true',
        help='Compare outputs with baseline'
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Show detailed diff information'
    )
    parser.add_argument(
        '--accept', '-a',
        metavar='FILE_PATTERN',
        help='Accept changes and update baseline for matching file(s)'
    )
    parser.add_argument(
        '--accept-all',
        action='store_true',
        help='Accept all changes and update all baselines'
    )
    parser.add_argument(
        '--status', '-s',
        action='store_true',
        help='Show baseline status'
    )
    
    args = parser.parse_args()
    
    # Determine test directory
    script_dir = Path(__file__).parent
    manager = BaselineManager(str(script_dir))
    
    # Execute requested action
    if args.establish:
        manager.establish_baseline(force=args.force)
    elif args.compare:
        manager.compare_with_baseline(verbose=args.verbose)
    elif args.accept:
        manager.accept_changes(file_pattern=args.accept)
    elif args.accept_all:
        manager.accept_changes(all_files=True)
    elif args.status:
        manager.show_status()
    else:
        # Default: compare with baseline
        manager.compare_with_baseline(verbose=args.verbose)


if __name__ == "__main__":
    main()
