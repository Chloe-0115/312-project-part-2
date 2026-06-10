# Tear down Part 2 resources
# Ref: https://docs.aws.amazon.com/cli/latest/reference/ec2/
$ErrorActionPreference = "Stop"
$Region = "us-east-1"

$envFile = "$PSScriptRoot\..\instance.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { Set-Variable -Name $Matches[1] -Value $Matches[2] }
    }
    if ($instance_id) {
        Write-Host "Terminating instance $instance_id..."
        # Ref: https://docs.aws.amazon.com/cli/latest/reference/ec2/terminate-instances.html
        aws ec2 terminate-instances --instance-ids $instance_id --region $Region | Out-Null
        # Must wait before deleting the security group; SG is still attached while instance shuts down.
        # Ref: https://docs.aws.amazon.com/cli/latest/reference/ec2/wait/instance-terminated.html
        aws ec2 wait instance-terminated --instance-ids $instance_id --region $Region
    }
    Remove-Item $envFile -Force
}

$SgId = aws ec2 describe-security-groups --filters "Name=group-name,Values=ProjectP2" --query "SecurityGroups[0].GroupId" --output text --region $Region 2>$null
if ($SgId -and $SgId -ne "None") {
    Write-Host "Deleting security group $SgId..."
    aws ec2 delete-security-group --group-id $SgId --region $Region
}

Write-Host "Cleanup complete."
