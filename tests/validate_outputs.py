#!/usr/bin/env python3
"""
Output validation script for Citizen post processor testing
Compares generated NC code with expected outputs
"""

import os
import sys
import difflib
from pathlib import Path
from typing import Dict, List, Tuple
import hashlib


class OutputValidator:
    def __init__(self, test_dir: str):
        self.test_dir = Path(test_dir)
        self.output_dir = self.test_dir / "output"
        self.expected_dir = self.test_dir / "expected"
    
    def normalize_nc_code(self, content: str) -> List[str]:
        """Normalize NC code for comparison (remove comments, normalize whitespace)"""
        lines = []
        for line in content.split('\n'):
            # Remove comments
            if '(' in line:
                line = line[:line.index('(')]
            # Strip whitespace
            line = line.strip()
            # Skip empty lines
            if line:
                # Normalize multiple spaces
                line = ' '.join(line.split())
                lines.append(line)
        return lines
    
    def find_generated_outputs(self) -> Dict[str, Path]:
        """Find all generated NC files in output directory"""
        if not self.output_dir.exists():
            print(f"Output directory not found: {self.output_dir}")
            return {}
        
        outputs = {}
        for nc_file in self.output_dir.glob("**/*.nc"):
            outputs[nc_file.stem] = nc_file
        
        return outputs
    
    def find_expected_output(self, output_name: str) -> Path:
        """Find expected output matching generated output name"""
        # Search through expected directory structure
        for expected_file in self.expected_dir.glob("**/*.nc"):
            if expected_file.stem == output_name or expected_file.name == f"{output_name}.nc":
                return expected_file
        
        return None
    
    def compare_files(self, generated: Path, expected: Path) -> Dict:
        """Compare two NC files and return detailed results"""
        try:
            with open(generated, 'r', encoding='utf-8', errors='ignore') as f:
                gen_content = f.read()
            with open(expected, 'r', encoding='utf-8', errors='ignore') as f:
                exp_content = f.read()
            
            # File size comparison
            gen_size = len(gen_content)
            exp_size = len(exp_content)
            size_match = abs(gen_size - exp_size) < (exp_size * 0.1)  # Within 10%
            
            # Normalize content
            gen_lines = self.normalize_nc_code(gen_content)
            exp_lines = self.normalize_nc_code(exp_content)
            
            # Line count comparison
            gen_line_count = len(gen_lines)
            exp_line_count = len(exp_lines)
            line_match = abs(gen_line_count - exp_line_count) < max(5, int(exp_line_count * 0.1))
            
            # Content similarity
            similarity = difflib.SequenceMatcher(None, gen_lines, exp_lines).ratio()
            
            # Generate diff
            diff = list(difflib.unified_diff(exp_lines[:20], gen_lines[:20], lineterm=''))
            
            return {
                "match": size_match and line_match and similarity > 0.85,
                "similarity": round(similarity * 100, 2),
                "gen_size": gen_size,
                "exp_size": exp_size,
                "size_match": size_match,
                "gen_lines": gen_line_count,
                "exp_lines": exp_line_count,
                "line_match": line_match,
                "diff_preview": diff[:10] if diff else []
            }
        except Exception as e:
            return {
                "match": False,
                "error": str(e)
            }
    
    def validate_all_outputs(self) -> Dict:
        """Validate all generated outputs against expected"""
        print("\n" + "="*60)
        print("Post Processor Output Validation")
        print("="*60)
        
        generated_outputs = self.find_generated_outputs()
        results = {}
        matches = 0
        mismatches = 0
        missing = 0
        
        if not generated_outputs:
            print("No generated outputs found in 'output' directory")
            print("Please generate NC files first using Fusion 360")
            return results
        
        print(f"\nFound {len(generated_outputs)} generated outputs\n")
        
        for output_name, gen_file in sorted(generated_outputs.items()):
            expected_file = self.find_expected_output(output_name)
            
            if not expected_file:
                print(f"⚠ {output_name:50s} - EXPECTED OUTPUT NOT FOUND")
                missing += 1
                results[output_name] = {"status": "missing", "file": str(gen_file)}
                continue
            
            comparison = self.compare_files(gen_file, expected_file)
            
            if comparison.get("error"):
                print(f"✗ {output_name:50s} - ERROR: {comparison['error']}")
                mismatches += 1
                results[output_name] = comparison
                continue
            
            if comparison["match"]:
                print(f"✓ {output_name:50s} - PASS ({comparison['similarity']}% match)")
                matches += 1
                results[output_name] = {"status": "pass", **comparison}
            else:
                print(f"✗ {output_name:50s} - MISMATCH ({comparison['similarity']}% match)")
                print(f"  Expected: {comparison['exp_lines']} lines, {comparison['exp_size']} bytes")
                print(f"  Generated: {comparison['gen_lines']} lines, {comparison['gen_size']} bytes")
                mismatches += 1
                results[output_name] = {"status": "fail", **comparison}
        
        # Summary
        print("\n" + "="*60)
        print("Validation Summary")
        print("="*60)
        print(f"✓ PASS:    {matches}")
        print(f"✗ FAIL:    {mismatches}")
        print(f"⚠ MISSING: {missing}")
        print(f"TOTAL:   {len(generated_outputs)}")
        
        pass_rate = (matches / len(generated_outputs) * 100) if generated_outputs else 0
        print(f"\nPass Rate: {pass_rate:.1f}%")
        
        return results
    
    def generate_html_report(self, results: Dict) -> str:
        """Generate an HTML report of validation results"""
        html = """
<!DOCTYPE html>
<html>
<head>
    <title>Post Processor Test Results</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        h1 { color: #333; }
        table { border-collapse: collapse; width: 100%; background-color: white; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .pass { background-color: #d4edda; color: #155724; }
        .fail { background-color: #f8d7da; color: #721c24; }
        .missing { background-color: #fff3cd; color: #856404; }
        .summary { background-color: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <h1>Post Processor Output Validation Report</h1>
"""
        
        # Summary statistics
        passed = sum(1 for r in results.values() if r.get("status") == "pass")
        failed = sum(1 for r in results.values() if r.get("status") == "fail")
        missing = sum(1 for r in results.values() if r.get("status") == "missing")
        
        html += f"""
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Total Tests:</strong> {len(results)}</p>
        <p><strong>Passed:</strong> {passed} ✓</p>
        <p><strong>Failed:</strong> {failed} ✗</p>
        <p><strong>Missing Expected:</strong> {missing} ⚠</p>
        <p><strong>Pass Rate:</strong> {(passed/len(results)*100):.1f}%</p>
    </div>
    
    <table>
        <tr>
            <th>Output File</th>
            <th>Status</th>
            <th>Similarity</th>
            <th>Generated Size</th>
            <th>Expected Size</th>
        </tr>
"""
        
        for output_name, result in sorted(results.items()):
            status = result.get("status", "unknown")
            status_class = f"class='{status}'"
            similarity = result.get("similarity", "N/A")
            gen_size = result.get("gen_size", "N/A")
            exp_size = result.get("exp_size", "N/A")
            
            html += f"""
        <tr {status_class}>
            <td>{output_name}.nc</td>
            <td>{status.upper()}</td>
            <td>{similarity}%</td>
            <td>{gen_size} bytes</td>
            <td>{exp_size} bytes</td>
        </tr>
"""
        
        html += """
    </table>
</body>
</html>
"""
        return html


def main():
    script_dir = Path(__file__).parent
    validator = OutputValidator(str(script_dir))
    results = validator.validate_all_outputs()
    
    # Generate HTML report
    html_report = validator.generate_html_report(results)
    report_file = script_dir / "VALIDATION_REPORT.html"
    with open(report_file, 'w') as f:
        f.write(html_report)
    print(f"\n✓ HTML report saved to: {report_file}")


if __name__ == "__main__":
    main()
