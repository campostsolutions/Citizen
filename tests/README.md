# Citizen Post Processor Testing Guide

## Overview

This directory contains the complete test infrastructure for validating Citizen post processors. The tests ensure that NC code generated from CAM files matches expected outputs for different machine types and post processors.

## Directory Structure

```
tests/
├── Parts/                    # Fusion 360 test files (.f3d)
│   └── Archive/             # Previous versions
├── expected/                 # Expected NC code outputs
│   ├── additive/
│   ├── jet/
│   ├── milling/
│   ├── milljet/
│   ├── millturn/
│   └── turning/
├── machine/                  # Machine configuration files
├── output/                   # Generated NC code (created during testing)
├── Posts/                    # Reserved for test post processors
├── test_cases/              # Test case configurations
├── cnc/                     # CNC output logs
├── test_runner.py           # Main test discovery and syntax checker
├── validate_outputs.py      # Output comparison and validation
└── README.md                # This file
```

## Quick Start

### Baseline Workflow (Recommended)

This approach establishes a baseline from your first set of outputs, then tracks changes.

#### Step 1: Generate NC Code

Using Fusion 360:
1. Open a test part from `Parts/` folder
2. Select "Output to Citizen" from CAM Actions
3. Generate NC code and save to `tests/output/` directory
   - Format: `<part_name>_<machine_name>_<operation_type>.nc`

#### Step 2: Run Tests

**Simple one-command test:**
```bash
cd tests
python quick_test.py
# or on Windows: run_tests.bat
```

**First run** - establishes baseline from current outputs:
```bash
python baseline_manager.py --establish
```

**Subsequent runs** - compares against baseline:
```bash
python baseline_manager.py --compare
```

#### Step 3: Review Results

- ✓ **Match** - Output matches baseline (no changes)
- ⚠ **Changed** - Output differs from baseline
- ✨ **New** - New output not in baseline yet

#### Step 4: Accept Changes (if needed)

Update baseline with new outputs:
```bash
# Accept all changes
python baseline_manager.py --accept-all

# Accept specific file
python baseline_manager.py --accept "Qatest-Mill"
```

### Alternative: Detailed Test Discovery

For comprehensive analysis without baseline tracking:

```bash
python test_runner.py
```

This will:
- List all 20+ post processors
- Verify post syntax
- Discover all test parts (11 CAM files)
- Generate detailed `TEST_REPORT.md`

### Alternative: Validate Against Expected Outputs

Compare with pre-existing expected outputs:

```bash
python validate_outputs.py
```

Generates HTML report with detailed comparisons.

## Available Post Processors

### Citizen Machines
- L12-VII
- L212-X
- L220-VIII, L220-X, L220-XII
- L32-VIII, L32-X, L32-XII
- L320-VIII, L320-X, L320-XII, L320-XIIB5
- M532-V, M532-VIII

### Miyano Machines
- ABX-SYY, ABX-THY
- ANX
- BNE-MYY

### Common/Utilities
- common700, common800
- toolpath sketcher

## Test Parts Available

1. **Qatest-Mill.f3d** - Milling operations (5-axis, index, etc.)
2. **Qatest-MillTurn.f3d** - Mill-turn simultaneous operations
3. **Qatest-Probing.f3d** - Probing/inspection operations
4. **Qatest-Stock Transfer.f3d** - Stock transfer and unload cycles
5. **Qatest-Cycle Subprograms.f3d** - Subprogram cycles
6. **Qatest-Deposition.f3d** - Additive operations
7. **QAtest-additive-fff.f3d** - FDM/FFF additive
8. **QAtest-Inspection.f3d** - Inspection operations
9. **QAtest-Laser-Waterjet-Plasma.f3d** - Jet operations
10. **QAtest-Indexing Pattern.f3d** - Complex indexing patterns
11. **QAtest-Router Test.f3d** - CNC router operations

## Machine Type Classifications

Outputs are organized by machine capability:

- **milling** - Milling-only machines
- **turning** - Turning-only machines  
- **millturn** - Simultaneous mill-turn machines
- **additive** - Additive manufacturing (3D printing, deposition)
- **jet** - Jet operations (laser, waterjet, plasma, etc.)
- **milljet** - Hybrid milling and jet operations

## Testing Workflow

### Baseline-Based Testing (Recommended for Regression Testing)

The baseline system provides a simple way to track changes over time:

1. **First time:** Establish baseline from initial outputs
   ```bash
   python baseline_manager.py --establish
   ```

2. **After code changes:** Run comparison
   ```bash
   python baseline_manager.py --compare
   # or: python quick_test.py
   ```

3. **Review results:**
   - ✓ **MATCH** - Output identical to baseline (no regression)
   - ⚠ **CHANGED** - Output differs from baseline (review changes)
   - ✨ **NEW** - New output not yet in baseline

4. **Accept changes** (if verified as correct):
   ```bash
   python baseline_manager.py --accept-all
   ```

### Baseline Storage

- **Baseline files:** `tests/baseline/` directory
- **Metadata:** `tests/baseline_metadata.json` (tracks file hashes)
- Not committed to git (local regression tracking)

### Baseline Comparison Features

- **Normalized comparison** - Comments and whitespace ignored
- **Hash-based tracking** - Detects any changes
- **Similarity scoring** - Shows % match with baseline
- **Size comparison** - Tracks byte and line count changes
- **Change details** - Shows what's different (in --verbose mode)

### Full Integration Test

```bash
# 1. Discover test structure
python test_runner.py

# 2. In Fusion 360:
#    - Generate NC code for each machine/post
#    - Save to output/ directory

# 3. First time: establish baseline
python baseline_manager.py --establish

# 4. Verify results look correct, then:
python quick_test.py
# Should show: "All outputs match baseline!"

# 5. After modifying posts, regenerate in Fusion 360, then:
python quick_test.py
# Will show which outputs changed

# 6. Review changes, then accept if correct:
python baseline_manager.py --accept-all
```

## Output Comparison Details

The validation script compares outputs by:

1. **File Size** - Within 10% of expected
2. **Line Count** - Within 5 lines or 10% of expected
3. **Content Similarity** - Using normalized line-by-line comparison
   - Comments are ignored
   - Whitespace is normalized
   - Target match: > 85% similarity

### Understanding Validation Results

- ✓ **PASS** - Output matches expected (>85% similarity, size/line count acceptable)
- ✗ **FAIL** - Output differs significantly from expected
- ⚠ **MISSING** - No expected output exists for comparison

## Expected Output Structure

Expected outputs are stored following this hierarchy:

```
expected/
├── milling/
│   ├── 5axismaker/
│   ├── acramatic/
│   ├── acurite millpwr 2/
│   ├── acurite millpwr 3/
│   └── ... (many more)
├── turning/
│   ├── citizen-l12-vii/
│   ├── citizen-l220-viii/
│   └── ... (many more)
└── ... (other machine types)
```

Each post directory contains reference NC files for comparison.

## CI/CD Integration

To integrate these tests into your CI/CD pipeline:

```yaml
# Example GitHub Actions workflow
test:
  runs-on: windows-latest
  steps:
    - uses: actions/checkout@v2
    - name: Discover tests
      run: python tests/test_runner.py
    - name: Validate outputs
      run: python tests/validate_outputs.py
    - name: Archive reports
      uses: actions/upload-artifact@v2
      with:
        name: test-reports
        path: |
          tests/TEST_REPORT.md
          tests/VALIDATION_REPORT.html
```

## Troubleshooting

### No outputs generated

1. Check that test parts exist in `Parts/` directory
2. Verify Fusion 360 can load the .f3d files
3. Ensure CAM setup and operations are configured correctly
4. Check post processor selection

### Outputs not validating

1. Ensure outputs are in correct directory: `tests/output/`
2. Check naming convention matches expected pattern
3. Review similarity score in `VALIDATION_REPORT.html`
4. Compare output with expected file manually using text editor

### Post processor syntax errors

1. Run `python test_runner.py` to check post syntax
2. Review indicated issues (e.g., "Missing machine definition")
3. Verify post file is valid CPS format

## Next Steps

1. Generate test outputs using Fusion 360
2. Run `python baseline_manager.py --establish` to create baseline
3. Run `python quick_test.py` for simple pass/fail comparison
4. After modifications, run `python baseline_manager.py --compare` to see changes
5. Accept changes with `python baseline_manager.py --accept-all`

## Command Reference

### Quick Test (One Command)
```bash
python quick_test.py              # Simple pass/fail comparison
# Windows: run_tests.bat
```

### Baseline Management
```bash
python baseline_manager.py --establish           # Create baseline from outputs
python baseline_manager.py --compare             # Compare against baseline
python baseline_manager.py --compare --verbose   # Show detailed diffs
python baseline_manager.py --status              # Show baseline info
python baseline_manager.py --accept-all          # Accept all changes
python baseline_manager.py --accept "filename"   # Accept specific file
python baseline_manager.py --establish --force   # Force overwrite baseline
```

### Test Discovery & Validation
```bash
python test_runner.py             # Discover posts and parts, syntax check
python validate_outputs.py        # Validate against expected/ (HTML report)
```

## Examples

### Workflow 1: First Time Setup

```bash
# Generate outputs in Fusion 360, save to output/

# Establish baseline
python baseline_manager.py --establish
# Output:
#  + Qatest-Mill_Citizen-L12-VII - ESTABLISHED baseline
#  + Qatest-Mill_Miyano-BNE-MYY - ESTABLISHED baseline
#  ... (establishes all files)

# Verify baseline created
python baseline_manager.py --status
# Shows files in baseline/

# Run test to confirm all match
python quick_test.py
# Output: "All tests PASS - outputs match baseline!"
```

### Workflow 2: After Modifying a Post Processor

```bash
# Regenerate outputs in Fusion 360 for modified post

# Check what changed
python baseline_manager.py --compare
# Output:
#  ✓ Qatest-Mill_Citizen-L220-VIII - MATCH
#  ⚠ Qatest-Mill_Citizen-L12-VII - CHANGED (92.5% similar)
#  ✓ Qatest-MillTurn - MATCH
#  ... (shows what changed)

# If changes look correct, accept them
python baseline_manager.py --accept-all

# Verify all pass again
python quick_test.py
# Output: "All tests PASS - outputs match baseline!"
```

### Workflow 3: Testing Single Post After Changes

```bash
# Regenerate outputs only for Citizen-L12-VII in Fusion 360

# Compare
python baseline_manager.py --compare --verbose
# Shows detailed diff for changed file

# Accept just that file's changes
python baseline_manager.py --accept "Citizen-L12-VII"
# Output: "→ Qatest-Mill_Citizen-L12-VII - UPDATED"

# Run full test
python quick_test.py
```

## Baseline Storage

- **Baseline files:** `tests/baseline/` directory (local, not in git)
- **Metadata:** `tests/baseline_metadata.json` (tracks file hashes)
- Used for regression testing and change tracking
- Can be rebuilt anytime with `--establish`
