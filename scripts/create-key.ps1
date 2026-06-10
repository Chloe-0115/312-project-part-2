# Create ProjectP2 key pair without overwriting a good .pem file on error.
# Ref: https://docs.aws.amazon.com/cli/latest/reference/ec2/create-key-pair.html
$ErrorActionPreference = "Stop"

function Format-PemKey([string]$Raw) {
    if ($Raw -match "`n" -and ($Raw.Split("`n").Count -ge 3)) {
        return $Raw.Trim() + "`n"
    }
    $header = "-----BEGIN RSA PRIVATE KEY-----"
    $footer = "-----END RSA PRIVATE KEY-----"
    $body = $Raw.Replace($header, "").Replace($footer, "").Trim() -replace '\s+', ''
    $lines = @($header)
    for ($i = 0; $i -lt $body.Length; $i += 64) {
        $len = [Math]::Min(64, $body.Length - $i)
        $lines += $body.Substring($i, $len)
    }
    $lines += $footer
    return ($lines -join "`n") + "`n"
}

function Save-PemFile([string]$Path, [string]$KeyMaterial) {
    $formatted = Format-PemKey $KeyMaterial
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $formatted, $utf8)
}

$Root = Split-Path $PSScriptRoot -Parent
$Pem = Join-Path $Root "ProjectP2.pem"
$KeyName = "ProjectP2"
$Region = "us-east-1"

# Fix an existing one-line .pem file in place.
if (Test-Path $Pem) {
    $raw = [System.IO.File]::ReadAllText($Pem)
    if ($raw -match "BEGIN RSA PRIVATE KEY" -and $raw -notmatch "`n") {
        Write-Host "Fixing broken one-line ProjectP2.pem ..."
        Save-PemFile $Pem $raw
        Write-Host "Fixed $Pem"
        exit 0
    }
    if ((Get-Item $Pem).Length -gt 100 -and $raw -match "`n") {
        Write-Host "ProjectP2.pem already exists and looks valid. Skipping."
        exit 0
    }
}

$ErrorActionPreference = "Continue"
aws ec2 describe-key-pairs --key-names $KeyName --region $Region 2>$null | Out-Null
$ErrorActionPreference = "Stop"

if ($LASTEXITCODE -eq 0) {
    if ((Test-Path $Pem) -and (Get-Item $Pem).Length -gt 100) {
        Write-Host "Key pair $KeyName exists in AWS and local .pem looks valid. Skipping."
        exit 0
    }
    Write-Host "Key pair exists in AWS but local .pem is missing or broken. Deleting old key pair..."
    aws ec2 delete-key-pair --key-name $KeyName --region $Region | Out-Null
}

Write-Host "Creating key pair $KeyName ..."
$keyMaterial = aws ec2 create-key-pair --key-name $KeyName --query "KeyMaterial" --output text --region $Region
if ($LASTEXITCODE -ne 0 -or -not $keyMaterial) { throw "create-key-pair failed" }

Save-PemFile $Pem $keyMaterial
Write-Host "Saved $Pem"
