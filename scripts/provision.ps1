# Provision EC2 + Security Group for Part 2 (AWS CLI only)
# Ref: https://docs.aws.amazon.com/cli/latest/reference/ec2/
$ErrorActionPreference = "Stop"

$Region = "us-east-1"
$KeyName = "ProjectP2"
$SgName = "ProjectP2"
$InstanceName = "Project part 2"
$InstanceType = "t3.small"
# /32 means only this one IP can connect on port 22
$SshCidr = "73.96.253.173/32"

Write-Host "Getting default VPC..."
# Ref: https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-vpcs.html
$VpcId = aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text --region $Region
if ($VpcId -eq "None" -or -not $VpcId) { throw "No default VPC found" }

Write-Host "Getting Amazon Linux 2023 AMI..."
# Pick the newest AL2023 x86_64 image owned by Amazon.
# Ref: https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-images.html
$AmiId = aws ec2 describe-images `
    --owners amazon `
    --filters "Name=name,Values=al2023-ami-2023*-x86_64" "Name=state,Values=available" `
    --query "sort_by(Images, &CreationDate)[-1].ImageId" `
    --output text --region $Region

Write-Host "Creating security group $SgName..."
# Ref: https://docs.aws.amazon.com/cli/latest/reference/ec2/create-security-group.html
$SgId = aws ec2 create-security-group `
    --group-name $SgName `
    --description "For part 2" `
    --vpc-id $VpcId `
    --query "GroupId" --output text --region $Region 2>$null

if (-not $SgId) {
    # Group name already taken from a previous run; look it up instead of failing.
    $SgId = aws ec2 describe-security-groups --filters "Name=group-name,Values=$SgName" --query "SecurityGroups[0].GroupId" --output text --region $Region
    Write-Host "Security group already exists: $SgId"
} else {
    # Port 22 is for configure.ps1 (SSH). Port 25565 is for Minecraft clients and nmap.
    # Ref: https://docs.aws.amazon.com/cli/latest/reference/ec2/authorize-security-group-ingress.html
    aws ec2 authorize-security-group-ingress --group-id $SgId --protocol tcp --port 22 --cidr $SshCidr --region $Region | Out-Null
    aws ec2 authorize-security-group-ingress --group-id $SgId --protocol tcp --port 25565 --cidr "0.0.0.0/0" --region $Region | Out-Null
    Write-Host "Security group created: $SgId"
}

Write-Host "Launching EC2 instance..."
# Ref: https://docs.aws.amazon.com/cli/latest/reference/ec2/run-instances.html
$InstanceId = aws ec2 run-instances `
    --image-id $AmiId `
    --instance-type $InstanceType `
    --key-name $KeyName `
    --security-group-ids $SgId `
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$InstanceName}]" `
    --query "Instances[0].InstanceId" --output text --region $Region

Write-Host "Waiting for instance to run..."
# Blocks until the instance reaches the running state.
# Ref: https://docs.aws.amazon.com/cli/latest/reference/ec2/wait/instance-running.html
aws ec2 wait instance-running --instance-ids $InstanceId --region $Region

$PublicIp = aws ec2 describe-instances --instance-ids $InstanceId --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $Region

# Saved for configure.ps1 and destroy.ps1
@"
instance_id=$InstanceId
public_ip=$PublicIp
security_group_id=$SgId
"@ | Set-Content -Encoding utf8 "$PSScriptRoot\..\instance.env"

Write-Host ""
Write-Host "Done!"
Write-Host "Instance ID: $InstanceId"
Write-Host "Public IP:   $PublicIp"
