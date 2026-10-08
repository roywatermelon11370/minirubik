param(
    [string]$Ripes = 'C:\Data\Ripes-v2.2.6-106-g5b8a616-win-x86_64\Ripes.exe',
    [ValidateSet('RV32_ISS','RV32_5S')][string]$Processor = 'RV32_ISS',
    [switch]$RequiredOnly,
    [switch]$AllDistance11,
    [switch]$InvalidInputs
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$build = Join-Path $root 'build'
& (Join-Path $root 'build.ps1') -ExpectedLength 11
$full = Get-Content (Join-Path $root 'solver.s') -Raw
$summary = @()
$cases = Get-Content (Join-Path $root 'tests.txt') | Where-Object { $_ -and -not $_.StartsWith('#') }
if ($RequiredOnly) { $cases = $cases | Select-Object -First 3 }
if ($AllDistance11) {
    $cases = Get-Content (Join-Path $root 'distance11.txt')
    if ($cases.Count -ne 2644) { throw 'Run host_check first: expected 2644 distance-11 inputs' }
}
if ($InvalidInputs) {
    $cases = @('1234567111111','123456711111111','02345671111111','82345671111111',
        '12345671111110','12345671111114','1234567111111a','11345671111111','12345671111112') |
        ForEach-Object { "$_|-1|" }
}
foreach ($case in $cases) {
    $parts = $case.Split('|')
    $state = $parts[0]; $length = [int]$parts[1]; $answer = $parts[2]
    $tag = "$Processor-$state"
    $asm = Join-Path $build "$tag.s"
    $source = $full.Replace('input_state: .string "21345671111111"', ('input_state: .string "' + $state + '"'))
    $source = $source.Replace('expected_length: .word 11', ('expected_length: .word ' + $length))
    [IO.File]::WriteAllText($asm, $source, [Text.UTF8Encoding]::new($false))
    $json = Join-Path $build "$tag.json"
    $stdout = Join-Path $build "$tag.stdout.txt"
    $stderr = Join-Path $build "$tag.stderr.txt"
    $args = @('--mode','cli','--src',('"' + $asm + '"'),'-t','asm','--proc',$Processor,
              '--iret','--exectime','--runinfo','--json','--output',('"' + $json + '"'),'--timeout','180000')
    $process = Start-Process -FilePath $Ripes -ArgumentList $args -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
    while (-not $process.WaitForExit(1000)) { }
    $out = [IO.File]::ReadAllText($stdout).Replace([string][char]0,'').Replace("`r`n","`n")
    $err = [IO.File]::ReadAllText($stderr)
    if ($InvalidInputs) {
        if ($out -notmatch '(?m)^FAIL: invalid cube input$' -or $out -notmatch 'Program exited with code: 2') {
            throw "Input rejection failed for $state : $out $err"
        }
    } elseif ($process.ExitCode -ne 0 -or $err -match 'ERROR' -or $out -notmatch '(?m)^PASS$') {
        throw "Ripes failed for $state (process status $($process.ExitCode)): $err $out"
    }
    if (-not $InvalidInputs -and -not $out.StartsWith($answer + "`nPASS`n")) { throw "Solution mismatch for $state : $out" }
    $report = Get-Content $json -Raw | ConvertFrom-Json
    if (@($report.runinfo.'ISA extensions').Count -ne 0) { throw 'ISA extensions must be disabled' }
    if ($report.runinfo.processor -ne $Processor) { throw 'Processor mismatch' }
    $row = [pscustomobject]@{ state=$state; length=$length; processor=$Processor;
        iret=$report.'# instructions retired'; execution_ms=$report.'execution time (ms)'; solution=$answer }
    $summary += $row
    Write-Host "$Processor $state : PASS, $($row.iret) retired instructions"
}
$label = if ($AllDistance11) { 'distance11-' } elseif ($InvalidInputs) { 'invalid-' } else { '' }
$summary | ConvertTo-Json | Set-Content (Join-Path $root "results-$label$Processor.json") -Encoding utf8
