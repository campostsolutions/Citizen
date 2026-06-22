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

### 1. Discover Available Tests

Run the test discovery script to see all available posts and test parts:

```bash
python test_runner.py
```

This will:
- List all 20+ post processors
- Verify post syntax
- Discover all test parts (11 CAM files)
- Generate a detailed `TEST_REPORT.md`

### 2. Generate NC Code from Test Parts

Using Fusion 360:

1. Open a test part from `Parts/` folder
   - Example: `Qatest-Mill.f3d` for milling operations
   - Example: `Qatest-MillTurn.f3d` for turning operations

2. Select "Output to Citizen" from CAM Actions
3. Choose the appropriate machine/post from the dropdown
4. Generate NC code
5. Save outputs to the `output/` directory with naming convention:
   - Format: `<part_name>_<machine_name>_<operation_type>.nc`
   - Example: `Qatest-Mill_Citizen-L12-VII_milling.nc`

### 3. Validate Generated Outputs

Compare your generated outputs with expected results:

```bash
python validate_outputs.py
```

This will:
- Find all NC files in the `output/` directory
- Match them against expected outputs in the `expected/` directory
- Generate an HTML report with detailed comparisons
- Show pass/fail status and similarity scores

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

### Full Integration Test

```bash
# 1. Discover what needs testing
python test_runner.py

# 2. In Fusion 360:
#    - Generate NC code for each machine/post combination
#    - Save to output/ directory
#    - Use consistent naming convention

# 3. Validate all outputs
python validate_outputs.py

# 4. Review results
# - Check VALIDATION_REPORT.html in browser
# - Review TEST_REPORT.md for structure
```

### Regression Testing

After modifying a post processor:

1. Generate test output for that post
2. Run validation
3. Compare similarity scores with previous runs
4. Ensure all outputs are > 85% similar to expected

### Single Post Testing

To test a specific post processor:

1. In Fusion 360, select only that post
2. Generate outputs for key test parts
3. Validate with `python validate_outputs.py`

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
2. Run validation to establish baseline
3. Create automated workflows for regression testing
4. Set up notifications for failing tests
5. Integrate with development workflow

## Support

For questions about specific post processors, see:
- `Current Release/posts/` - Active post processor files
- `HTMLFusiontoCitizen/` - Fusion 360 add-in source code
- Machine documentation files in parent directories
