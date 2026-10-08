param([string]$CC = 'gcc', [switch]$Render,
      [string]$LedBase = '', [int]$Delay = 1000000)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
New-Item -ItemType Directory -Force (Join-Path $root 'build') | Out-Null
$generator = Join-Path $root 'build/generate_tables.exe'
& $CC -O3 -std=c99 -Wall -Wextra -Wpedantic (Join-Path $root 'generate_tables.c') -o $generator
if ($LASTEXITCODE -ne 0) { throw 'Coordinates table generator compilation failed' }
$tables = & $generator
if ($LASTEXITCODE -ne 0) { throw 'Coordinates table generation failed' }
$ctables = & $generator --c
if ($LASTEXITCODE -ne 0) { throw 'Coordinate C table generation failed' }
[IO.File]::WriteAllText((Join-Path $root 'build/tables.h'), ($ctables -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $root 'tables.s'), ($tables -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
$linkScript = (Join-Path $root 'link.sh').Replace('\','/')
$linkScript = '/mnt/' + $linkScript.Substring(0,1).ToLower() + $linkScript.Substring(2)
if ($Delay -lt 0) { throw 'Delay must be nonnegative' }
if ($Render) {
    if ($LedBase -notmatch '^0x[0-9a-fA-F]{1,8}$') {
        throw 'Supply -LedBase with the LED_MATRIX_0_BASE shown in Ripes I/O Exports (hexadecimal)'
    }
    & wsl -- sh $linkScript solver.s solver-led.elf 1 $LedBase $Delay
} else {
    & wsl -- sh $linkScript
}
if ($LASTEXITCODE -ne 0) { throw 'Separate RV32I object assembly/link/audit failed' }
Write-Host 'Created tables.s and linked the selected ELF; solver.s remains a separate source file.'
