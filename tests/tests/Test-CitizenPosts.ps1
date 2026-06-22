#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test runner for Citizen posts using the existing test infrastructure

.DESCRIPTION
Runs the Node.js-based test system against Citizen posts in the 
Current Release/posts directory

.EXAMPLE
# Test a single post
.\Test-CitizenPosts.ps1 "Citizen L320-VIII"

# Test all Citizen posts
.\Test-CitizenPosts.ps1 -All

# Test and recreate expected outputs
.\Test-CitizenPosts.ps1 -All -Recreate

.PARAMETER PostName
Name of the post to test (without .cps extension)

.PARAMETER All
Test all Citizen posts

.PARAMETER Recreate
Recreate expected output files (instead of comparing)

.PARAMETER ShowOutput
Show test output files after completion
#>

param(
    [string]$PostName,
    [switch]$All,
    [switch]$Recreate,
    [switch]$ShowOutput
)

# Get paths
$TestsDir = $PSScriptRoot
$PostsDir = Join-Path (Split-Path -Parent $TestsDir) "Current Release\posts"
$RunnerScript = Join-Path $TestsDir "run-tests.js"

if (-not (Test-Path $PostsDir)) {
    Write-Error "Posts directory not found: $PostsDir"
    exit 1
}

if (-not (Test-Path $RunnerScript)) {
    Write-Error "Test runner not found: $RunnerScript"
    exit 1
}

# List of all Citizen/Miyano posts
$CitizenPosts = @(
    "Citizen L12-VII",
    "Citizen L212-X",
    "Citizen L220-VIII",
    "Citizen L220-X",
    "Citizen L220-XII",
    "Citizen L32-VIII",
    "Citizen L32-X",
    "Citizen L32-XII",
    "Citizen L320-VIII",
    "Citizen L320-X",
    "Citizen L320-XII",
    "Citizen L320-XIIB5",
    "Citizen M532-V",
    "Citizen M532-VIII",
    "Miyano ABX-SYY",
    "Miyano ABX-THY",
    "Miyano ANX",
    "Miyano BNE-MYY"
)

function Test-SinglePost {
    param([string]$Name)
    
    $PostFile = "$Name.cps"
    $PostPath = Join-Path $PostsDir $PostFile
    
    if (-not (Test-Path $PostPath)) {
        Write-Warning "Post not found: $PostFile"
        return $false
    }
    
    $RunCmd = if ($Recreate) { "recreate-expected-single" } else { "run-single" }
    $BatFile = Join-Path $TestsDir "$RunCmd.bat"
    
    Write-Host "Testing: $Name" -ForegroundColor Cyan
    
    & $BatFile $PostPath
    
    return $LASTEXITCODE -eq 0
}

function Test-AllPosts {
    $Results = @{
        Passed = 0
        Failed = 0
        Skipped = 0
    }
    
    foreach ($Post in $CitizenPosts) {
        $PostFile = "$Post.cps"
        $PostPath = Join-Path $PostsDir $PostFile
        
        if (Test-Path $PostPath) {
            if (Test-SinglePost $Post) {
                $Results.Passed++
                Write-Host "  ✓ PASSED" -ForegroundColor Green
            } else {
                $Results.Failed++
                Write-Host "  ✗ FAILED" -ForegroundColor Red
            }
        } else {
            $Results.Skipped++
            Write-Host "  ⚠ SKIPPED (not found)" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    return $Results
}

# Main execution
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Citizen Post Processor Test Runner" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

if ($All) {
    Write-Host "Testing ALL Citizen posts..." -ForegroundColor Green
    Write-Host ""
    $Results = Test-AllPosts
    
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "Test Summary" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "Passed:  $($Results.Passed)" -ForegroundColor Green
    Write-Host "Failed:  $($Results.Failed)" -ForegroundColor $(if ($Results.Failed -gt 0) { 'Red' } else { 'Green' })
    Write-Host "Skipped: $($Results.Skipped)" -ForegroundColor Yellow
    Write-Host ""
    
    if ($Results.Failed -gt 0) {
        Write-Host "Some tests FAILED" -ForegroundColor Red
        exit 1
    }
} elseif ($PostName) {
    Write-Host "Testing: $PostName" -ForegroundColor Green
    Write-Host ""
    
    if (Test-SinglePost $PostName) {
        Write-Host "Test PASSED" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Test FAILED" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Available posts:" -ForegroundColor Cyan
    $CitizenPosts | ForEach-Object { Write-Host "  - $_" }
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "  # Test single post"
    Write-Host "  .\Test-CitizenPosts.ps1 'Citizen L320-VIII'"
    Write-Host ""
    Write-Host "  # Test all posts"
    Write-Host "  .\Test-CitizenPosts.ps1 -All"
    Write-Host ""
    Write-Host "  # Recreate expected outputs"
    Write-Host "  .\Test-CitizenPosts.ps1 -All -Recreate"
    Write-Host ""
    exit 0
}

# Show output if requested
if ($ShowOutput) {
    $OutputDir = Join-Path $TestsDir "output"
    if (Test-Path $OutputDir) {
        Write-Host "Opening output directory..." -ForegroundColor Cyan
        Invoke-Item $OutputDir
    }
}
