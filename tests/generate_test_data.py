#!/usr/bin/env python3
"""
Synthetic Test Data Generator
Creates realistic NC code for testing the testing infrastructure
Useful for development and CI/CD without Fusion 360
"""

import random
import string
from pathlib import Path


class NCCodeGenerator:
    """Generates synthetic but realistic NC code"""
    
    @staticmethod
    def generate_milling_code(part_name: str, machine: str) -> str:
        """Generate realistic milling NC code"""
        code_lines = [
            f"% Test NC File: {part_name} - {machine}",
            f"(Generated for: {machine})",
            "(Milling Operation)",
            "",
            "G91 G28 Z0.",
            "G90",
            "G21",
            "",
            "(Tool 1: 10mm End Mill)",
            "T1M06",
            "G00 X10.0 Y10.0",
            "G43 Z10.0 H1",
            "G01 Z-5.0 F100.0",
            "",
        ]
        
        # Add some random milling moves
        for i in range(15):
            x = random.uniform(10, 100)
            y = random.uniform(10, 100)
            f = random.choice([100, 150, 200])
            code_lines.append(f"G01 X{x:.2f} Y{y:.2f} F{f}")
        
        code_lines.extend([
            "",
            "G00 Z10.0",
            "G91 G28 Z0.",
            "G91 G28 X0 Y0",
            "M30",
            "%"
        ])
        
        return "\n".join(code_lines)
    
    @staticmethod
    def generate_turning_code(part_name: str, machine: str) -> str:
        """Generate realistic turning NC code"""
        code_lines = [
            f"% Test NC File: {part_name} - {machine}",
            f"(Generated for: {machine})",
            "(Turning Operation)",
            "",
            "G90",
            "G21",
            "G40",
            "",
            "(Tool 1: Finishing Tool)",
            "T0101",
            "G00 X50.0 Z2.0",
            "G01 Z-30.0 F0.3",
            "G00 X52.0",
            "",
        ]
        
        # Add some turning moves
        for i in range(10):
            z = random.uniform(-50, 0)
            f = random.choice([0.2, 0.3, 0.4])
            code_lines.append(f"G01 Z{z:.2f} F{f}")
        
        code_lines.extend([
            "",
            "G00 X100.0 Z50.0",
            "M30",
            "%"
        ])
        
        return "\n".join(code_lines)
    
    @staticmethod
    def generate_millturn_code(part_name: str, machine: str) -> str:
        """Generate realistic mill-turn NC code"""
        code_lines = [
            f"% Test NC File: {part_name} - {machine}",
            f"(Generated for: {machine})",
            "(Mill-Turn Operation)",
            "",
            "G90",
            "G21",
            "",
            "(Milling Phase)",
            "G00 X20.0 Y20.0",
            "G01 Z-10.0 F100",
            "",
        ]
        
        for i in range(8):
            x = random.uniform(20, 80)
            y = random.uniform(20, 80)
            code_lines.append(f"G01 X{x:.2f} Y{y:.2f} F{random.choice([100, 150])}")
        
        code_lines.extend([
            "",
            "(Turning Phase)",
            "G00 X50.0 Z2.0",
            "G01 Z-20.0 F0.3",
            "",
        ])
        
        for i in range(6):
            z = random.uniform(-30, 0)
            code_lines.append(f"G01 Z{z:.2f} F{random.choice([0.2, 0.3])}")
        
        code_lines.extend([
            "",
            "G00 X100.0 Z50.0",
            "M30",
            "%"
        ])
        
        return "\n".join(code_lines)


def generate_test_outputs(test_dir: Path, num_files: int = 10) -> int:
    """Generate synthetic test files"""
    
    output_dir = test_dir / "output"
    output_dir.mkdir(exist_ok=True)
    
    generators = {
        "milling": NCCodeGenerator.generate_milling_code,
        "turning": NCCodeGenerator.generate_turning_code,
        "millturn": NCCodeGenerator.generate_millturn_code,
    }
    
    posts = [
        "Citizen-L12-VII",
        "Citizen-L220-VIII",
        "Citizen-L320-X",
        "Miyano-BNE-MYY",
        "Miyano-ABX-SYY",
    ]
    
    parts = [
        "Qatest-Mill",
        "Qatest-MillTurn",
        "Qatest-Probing",
    ]
    
    print(f"\nGenerating {num_files} synthetic NC test files...\n")
    
    created = 0
    for i in range(num_files):
        operation_type = random.choice(list(generators.keys()))
        post = random.choice(posts)
        part = random.choice(parts)
        
        filename = f"{part}_{post}_{operation_type}.nc"
        filepath = output_dir / filename
        
        # Skip if already exists
        if filepath.exists():
            continue
        
        # Generate content
        content = generators[operation_type](part, post)
        
        # Write file
        with open(filepath, 'w') as f:
            f.write(content)
        
        print(f"+ {filename:50s}")
        created += 1
        
        if created >= num_files:
            break
    
    print(f"\n✓ Generated {created} test files")
    return created


def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Generate synthetic test data for testing infrastructure'
    )
    parser.add_argument(
        '--count', '-c',
        type=int,
        default=10,
        help='Number of test files to generate (default: 10)'
    )
    parser.add_argument(
        '--clear',
        action='store_true',
        help='Clear output directory first'
    )
    
    args = parser.parse_args()
    
    script_dir = Path(__file__).parent
    output_dir = script_dir / "output"
    
    # Clear if requested
    if args.clear and output_dir.exists():
        import shutil
        print(f"Clearing output directory...")
        shutil.rmtree(output_dir)
        output_dir.mkdir()
    
    # Generate test files
    count = generate_test_outputs(script_dir, num_files=args.count)
    
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
