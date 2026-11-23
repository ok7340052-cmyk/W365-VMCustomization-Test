$env:Path = @(
    [Environment]::GetEnvironmentVariable('Path', 'User')
) -join ';'

$git = Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue

if (-not $git) {
    exit 1
}

Write-Output 'Detected: git'
exit 0