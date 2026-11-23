$env:Path = @(
    [Environment]::GetEnvironmentVariable('Path', 'Machine')
    [Environment]::GetEnvironmentVariable('Path', 'User')
) -join ';'

$dotnet = Get-Command dotnet.exe -CommandType Application -ErrorAction SilentlyContinue

if (-not $dotnet) {
    exit 1
}

Write-Output 'Detected: dotnet'
exit 0