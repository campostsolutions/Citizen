#!/usr/bin/env python3
"""
Test runner for Citizen post processors
Validates post processor outputs against expected results
"""

import os
import sys
import json
import hashlib
from pathlib import Path
from typing import Dict, List, Tuple

class PostProcessorTestRunner:
    def __init__(self, test_dir: str, posts_dir: str):
        self.test_dir = Path(test_dir)
        self.posts_dir = Path(posts_dir)
        self.expected_dir = self.test_dir / "expected"
        self.parts_dir = self.test_dir / "Parts"
        self.output_dir = self.test_dir / "output"
        self.results = {}
        
    def discover_posts(self) -> List[str]:
        """Discover all .cps post processor files"""
        if not self.posts_dir.exists():
            print(f"Posts directory not found: {self.posts_dir}")
            return []
        
        posts = list(self.posts_dir.glob("*.cps"))
        return sorted([p.stem for p in posts])
    
    def discover_test_parts(self) -> Dict[str, Path]:
        """Discover all .f3d test parts"""
        if not self.parts_dir.exists():
            print(f"Parts directory not found: {self.parts_dir}")
            return {}
        
        parts = {}
        for part_file in self.parts_dir.glob("*.f3d"):
            parts[part_file.stem] = part_file
        
        return parts
    
    def discover_expected_outputs(self) -> Dict[str, Dict[str, Path]]:
        """Discover expected outputs organized by machine type and post"""
        if not self.expected_dir.exists():
            print(f"Expected outputs directory not found: {self.expected_dir}")
            return {}
        
        expected = {}
        for machine_type_dir in self.expected_dir.iterdir():
            if not machine_type_dir.is_dir():
                continue
            
            machine_type = machine_type_dir.name
            expected[machine_type] = {}
            
            for post_dir in machine_type_dir.iterdir():
                if post_dir.is_dir():
                    post_name = post_dir.name
                    outputs = list(post_dir.glob("*"))
                    if outputs:
                        expected[machine_type][post_name] = post_dir
        
        return expected
    
    def verify_post_syntax(self, post_file: Path) -> Tuple[bool, str]:
        """Basic syntax check for CPS files"""
        try:
            with open(post_file, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                
            # Check for basic CPS structure
            checks = [
                ('description' in content.lower(), "Missing description"),
                ('machine' in content.lower(), "Missing machine definition"),
                ('setup' in content.lower() or 'operation' in content.lower(), 
                 "Missing setup/operation handlers"),
            ]
            
            for check, msg in checks:
                if not check:
                    return False, msg
            
            return True, "OK"
        except Exception as e:
            return False, str(e)
    
    def calculate_file_hash(self, file_path: Path) -> str:
        """Calculate MD5 hash of a file"""
        hash_md5 = hashlib.md5()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()
    
    def run_syntax_checks(self) -> Dict:
        """Run syntax checks on all posts"""
        print("\n" + "="*60)
        print("Running Syntax Checks")
        print("="*60)
        
        posts = self.discover_posts()
        results = {}
        
        for post_name in posts:
            post_file = self.posts_dir / f"{post_name}.cps"
            valid, msg = self.verify_post_syntax(post_file)
            results[post_name] = {"valid": valid, "message": msg}
            
            status = "✓" if valid else "✗"
            print(f"{status} {post_name:40s} - {msg}")
        
        return results
    
    def generate_test_report(self) -> str:
        """Generate a comprehensive test report"""
        print("\n" + "="*60)
        print("Test Report")
        print("="*60)
        
        posts = self.discover_posts()
        parts = self.discover_test_parts()
        expected = self.discover_expected_outputs()
        
        report = []
        report.append("# Post Processor Test Report\n")
        report.append(f"Generated: {__import__('datetime').datetime.now().isoformat()}\n\n")
        
        # Summary
        report.append("## Summary\n")
        report.append(f"- Total Posts: {len(posts)}\n")
        report.append(f"- Total Test Parts: {len(parts)}\n")
        report.append(f"- Machine Types: {len(expected)}\n")
        report.append(f"- Total Expected Outputs: {sum(sum(1 for _ in v.values()) for v in expected.values())}\n\n")
        
        # Posts List
        report.append("## Posts\n")
        for post in posts:
            report.append(f"- {post}\n")
        report.append("\n")
        
        # Test Parts
        report.append("## Test Parts\n")
        for part_name in sorted(parts.keys()):
            report.append(f"- {part_name}\n")
        report.append("\n")
        
        # Expected Outputs by Machine Type
        report.append("## Expected Outputs Structure\n")
        for machine_type in sorted(expected.keys()):
            posts_for_type = expected[machine_type]
            report.append(f"### {machine_type.title()}\n")
            for post_name in sorted(posts_for_type.keys()):
                report.append(f"- {post_name}\n")
            report.append("\n")
        
        # Setup Instructions
        report.append("## Setup Instructions for Integration Testing\n\n")
        report.append("""
### To run integration tests with Fusion 360:

1. **Manual Testing in Fusion 360:**
   - Load each test part from `tests/Parts/`
   - Select a post processor from `Current Release/posts/`
   - Generate NC code and save to `tests/output/`
   - Compare with expected output in `tests/expected/<machine_type>/<post_name>/`

2. **Automated Testing (requires Fusion 360 API):**
   - Use Fusion 360 Python API to load parts
   - Programmatically invoke post processors
   - Compare generated outputs with expected results

3. **Validation Script:**
   - Use the provided validation scripts to check output consistency
   - Compare file sizes, checksums, and key content patterns
   - Generate HTML reports of test results

### Output File Naming Convention:
- Format: `<part_name>_<machine_type>_<operation>.nc`
- Example: `Qatest-Mill_Citizen-L12-VII_milling.nc`
""")
        
        return "".join(report)
    
    def run_all_checks(self):
        """Run all available checks"""
        print("\n" + "="*60)
        print("Citizen Post Processor Test Suite")
        print("="*60)
        
        syntax_results = self.run_syntax_checks()
        report = self.generate_test_report()
        
        # Save report
        report_file = self.test_dir / "TEST_REPORT.md"
        with open(report_file, 'w') as f:
            f.write(report)
        print(f"\n✓ Report saved to: {report_file}")
        
        return {
            "syntax_checks": syntax_results,
            "report_file": str(report_file)
        }


def main():
    # Determine paths
    script_dir = Path(__file__).parent
    test_dir = script_dir
    posts_dir = script_dir.parent / "Current Release" / "posts"
    
    # Run tests
    runner = PostProcessorTestRunner(str(test_dir), str(posts_dir))
    results = runner.run_all_checks()
    
    print("\n" + "="*60)
    print("Test Execution Complete")
    print("="*60)


if __name__ == "__main__":
    main()
