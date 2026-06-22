# Testing Citizen Posts with the Existing Test Infrastructure

The test system in this directory can run tests against any posts, including those in the `Current Release/posts/` directory.

## Quick Start

### Option 1: Batch File (Easiest for Windows)

**Test a single post:**
```batch
run-citizen-tests.bat "Citizen L320-VIII"
```

**Test all Citizen posts:**
```batch
run-all-citizen-posts.bat
```

### Option 2: PowerShell (More Flexible)

**Test a single post:**
```powershell
.\Test-CitizenPosts.ps1 "Citizen L320-VIII"
```

**Test all Citizen posts:**
```powershell
.\Test-CitizenPosts.ps1 -All
```

**Recreate expected outputs for all posts:**
```powershell
.\Test-CitizenPosts.ps1 -All -Recreate
```

**Show output after testing:**
```powershell
.\Test-CitizenPosts.ps1 -All -ShowOutput
```

### Option 3: Manual Node.js Runner

Use the existing test infrastructure directly:

```bash
node run-tests.js --postEngine=[path] --tests=[test_cases] --posts=[posts_dir]
```

## What Gets Tested

### Posts
All posts in `../Current Release/posts/`:
- Citizen L-Series (L12-VII, L220-VIII, L320-X, etc.)
- Citizen M-Series (M532-V, M532-VIII)
- Miyano machines (ABX-SYY, BNE-MYY, ANX, etc.)
- Common libraries (common700, common800)

### Test Cases
Test cases defined in `test_cases/` directory:
- **Milling** - 5-axis, interpolated, probing, etc.
- **Turning** - Various turning profiles
- **Mill-Turn** - Simultaneous mill-turn operations
- **Jet** - Laser, waterjet, plasma operations
- **Additive** - 3D printing, deposition
- **Mill-Jet** - Hybrid milling and jet operations

## Output Structure

After running tests:

```
output/
├── [post-name]_[test-case]_[timestamp].nc     # Generated NC files
├── [post-name]_[test-case]_[timestamp].log    # Test logs
└── ...
```

Compare outputs with expected results in `expected/` directory.

## Troubleshooting

### "No test cases found for post"

This means there's no test case definition for that post. Test cases are defined in JSON files in the `test_cases/` directory.

To create a test case:
1. Create a JSON file in the appropriate subdirectory (e.g., `test_cases/milling/`)
2. Name it after the post (e.g., `citizen-l320-viii.json`)
3. Define test cases following the format in the README

### "Post not found"

Verify the post exists:
```powershell
Get-ChildItem "..\Current Release\posts\*.cps"
```

### Post engine errors

The test system uses a post engine (`post.exe`). If errors occur:
1. Check that the post engine path is correct (see `run-all.bat` for path)
2. Verify all post files are valid CPS format
3. Check post dependencies (e.g., does it include common700.cps?)

## Using vs. Creating Test Cases

### Use Existing Tests
The system includes test cases for many posts. To test a post that already has test cases:

```powershell
.\Test-CitizenPosts.ps1 "Citizen L320-VIII"
```

### Create New Test Cases
If a Citizen post doesn't have test cases, create one:

1. Create JSON file: `test_cases/[operation]/citizen-[model].json`
2. Define test cases following the schema in the main README
3. Re-run tests

## Advanced Usage

### Recreate Expected Outputs
Update the reference outputs (run after verifying outputs are correct):

```batch
run-single.bat "..\Current Release\posts\Citizen L320-VIII.cps"
recreate-expected-single.bat "..\Current Release\posts\Citizen L320-VIII.cps"
```

Or via PowerShell:
```powershell
.\Test-CitizenPosts.ps1 "Citizen L320-VIII" -Recreate
```

### Run All Tests with Custom Post Engine
```batch
run-all.bat [path-to-post.exe]
```

### View Diffs
Use external diff tools configured in `settings.json`:

```powershell
node run-tests.js --externalDiff
```

## Integration with CI/CD

The Node.js test runner supports exit codes for CI/CD integration:
- Exit code 0: All tests passed
- Exit code 1: One or more tests failed

Example GitHub Actions:
```yaml
- name: Test Citizen Posts
  run: |
    cd tests/tests
    node run-tests.js --tests=test_cases --posts="../../Current Release/posts"
```

## Files in This Directory

| File | Purpose |
|------|---------|
| `run-tests.js` | Core Node.js test runner |
| `run-single.bat` | Run tests for one post (original) |
| `run-all.bat` | Run tests for all posts (original) |
| `run-citizen-tests.bat` | Wrapper for testing Citizen posts |
| `run-all-citizen-posts.bat` | Test all Citizen posts at once |
| `Test-CitizenPosts.ps1` | PowerShell wrapper (recommended) |
| `test_cases/` | Test case definitions (JSON) |
| `expected/` | Expected output files (reference) |
| `output/` | Generated output files (created during tests) |
| `settings.json` | Test system configuration |
