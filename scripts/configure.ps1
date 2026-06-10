# Configure Minecraft on the EC2 instance (automated, no manual SSH in demo)
# Ref: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-linux-inst-ssh.html
$ErrorActionPreference = "Stop"

$Root = Split-Path $PSScriptRoot -Parent
$EnvFile = Join-Path $Root "instance.env"
$Pem = Join-Path $Root "ProjectP2.pem"
$SetupScript = Join-Path $PSScriptRoot "setup-minecraft.sh"

# Skip host key prompts so the script can run without user input.
# UserKnownHostsFile=NUL avoids writing to known_hosts on Windows.
$SshOpts = @("-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=NUL", "-o", "LogLevel=ERROR")

if (-not (Test-Path $EnvFile)) { throw "Run provision.ps1 first" }
if (-not (Test-Path $Pem)) { throw "ProjectP2.pem not found. Run create-key.ps1 first." }
if ((Get-Item $Pem).Length -lt 100) { throw "ProjectP2.pem is empty or broken. Run create-key.ps1, then provision.ps1 again." }

Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') { Set-Variable -Name $Matches[1] -Value $Matches[2] }
}

Write-Host "Waiting for SSH on $public_ip (usually 1-3 minutes after provision) ..."
# EC2 can be "running" before sshd is ready; poll until SSH responds.
$ready = $false
for ($i = 1; $i -le 36; $i++) {
    Write-Host "  attempt $i/36 ..."
    $ErrorActionPreference = "Continue"
    $result = & ssh -i $Pem @SshOpts -o ConnectTimeout=5 "ec2-user@$public_ip" "echo ok" 2>$null
    $exit = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if ($exit -eq 0 -and $result -eq "ok") { $ready = $true; break }
    Start-Sleep -Seconds 5
}
if (-not $ready) { throw "SSH not ready on $public_ip after 3 minutes. Check security group port 22." }
Write-Host "SSH is ready."

Write-Host "Uploading setup script..."
$ErrorActionPreference = "Continue"
& scp -i $Pem @SshOpts $SetupScript "ec2-user@${public_ip}:/tmp/setup-minecraft.sh" 2>$null
if ($LASTEXITCODE -ne 0) { throw "scp failed" }
$ErrorActionPreference = "Stop"

Write-Host "Running setup (may take a few minutes)..."
$ErrorActionPreference = "Continue"
& ssh -i $Pem @SshOpts "ec2-user@$public_ip" "chmod +x /tmp/setup-minecraft.sh && sudo bash /tmp/setup-minecraft.sh"
if ($LASTEXITCODE -ne 0) { throw "Minecraft setup failed" }
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Done! Test with:"
Write-Host "nmap -sV -Pn -p 25565 $public_ip"
