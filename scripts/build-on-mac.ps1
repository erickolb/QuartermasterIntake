param(
    [string]$Mac = 'erickolb@barovia.chateaulore.net',
    [string]$HostKeyAlias = 'barovia.local',
    [ValidateRange(1, 2147483647)][int]$BuildNumber = 1,
    [switch]$Test
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    New-Item -ItemType Directory -Force build, dist | Out-Null
    $archive = Join-Path $root 'build/source.tar.gz'
    & tar -czf $archive --exclude=xcuserdata --exclude='*.xcuserstate' ios scripts
    if ($LASTEXITCODE -ne 0) { throw 'Could not package the source.' }
    $sshOptions = @('-o', 'BatchMode=yes', '-o', "HostKeyAlias=$HostKeyAlias", '-o', 'ConnectTimeout=15')
    $remote = & ssh @sshOptions $Mac 'mkdir -p ~/QMIntakeBuilds && mktemp -d ~/QMIntakeBuilds/build.XXXXXX'
    if ($LASTEXITCODE -ne 0) { throw 'SSH authentication failed.' }
    $remote = ($remote -join "`n").Trim()
    if ($remote -notmatch '^/Users/[A-Za-z0-9._-]+/QMIntakeBuilds/build\.[A-Za-z0-9]+$') { throw 'Unexpected remote directory.' }
    Write-Host "Building in $remote"
    & scp @sshOptions $archive "${Mac}:$remote/source.tar.gz"
    if ($LASTEXITCODE -ne 0) { throw 'Source transfer failed.' }
    $script = if ($Test) { 'scripts/verify-on-mac.sh' } else { 'scripts/build-ipa.sh' }
    & ssh @sshOptions $Mac "cd '$remote' && tar -xzf source.tar.gz && BUILD_NUMBER=$BuildNumber bash $script"
    if ($LASTEXITCODE -ne 0) { throw "Build or tests failed. Inspect ${Mac}:$remote." }
    & scp @sshOptions "${Mac}:$remote/dist/QM-Intake.ipa" (Join-Path $root 'dist/QM-Intake.ipa')
    if ($LASTEXITCODE -ne 0) { throw 'IPA download failed.' }
    Get-FileHash -LiteralPath (Join-Path $root 'dist/QM-Intake.ipa') -Algorithm SHA256
} finally { Pop-Location }
