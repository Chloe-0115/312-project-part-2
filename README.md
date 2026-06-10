# 312 Project Part 2 — Minecraft on AWS (Automated)

This project sets up a Minecraft Java server on AWS EC2 using PowerShell scripts and the AWS CLI. Everything runs from the command line on Windows. You do not use the AWS Console. For the demo, you only run scripts and never type ssh yourself.

## Requirements

**Tools used:**
- Windows PowerShell
- AWS CLI 2.35.1
- OpenSSH (ssh and scp, built into Windows)
- Nmap 7.99
- AWS Academy Learner Lab

**Note:** AWS Academy blocks creating IAM roles, so SSM Run Command cannot be used in this lab. Configuration is done by `configure.ps1`, which automates the setup for you.

**AWS credentials setup:**

1. Start the lab on the AWS Academy page (green **Lab ready**).
2. Click **AWS CLI - Show** and copy all three lines.
3. Create the folder `C:\Users\<you>\.aws` if it does not exist.
4. Paste into `C:\Users\<you>\.aws\credentials`:

```ini
[default]
aws_access_key_id=...
aws_secret_access_key=...
aws_session_token=...
```

5. Create `C:\Users\<you>\.aws\config`:

```ini
[default]
region = us-east-1
output = json
```

6. Test with:

```powershell
aws sts get-caller-identity
```

You need new credentials each time you start a new lab session.

**What gets created in AWS:**
- EC2 instance `Project part 2` (Amazon Linux 2023, t3.small)
- Key pair `ProjectP2`
- Security group `ProjectP2` (SSH from your IP, port 25565 open to all)

## Pipeline Overview

1. `scripts/provision.ps1` — creates security group and EC2 instance
2. `scripts/configure.ps1` — runs `setup-minecraft.sh` on the instance (automated)
3. `scripts/setup-minecraft.sh` — installs Java 25, server jar, EULA, systemd
4. `nmap` — verifies port 25565 is open
5. `scripts/destroy.ps1` — deletes the instance and security group

## Tutorial

### Background

For Part 2 we put a Minecraft server on AWS EC2 and check that it is actually running. Part 1 was all manual; here we use scripts so everything can be done from the command line.

First, `provision.ps1` uses the AWS CLI to create the EC2 instance and security group. Then `configure.ps1` installs Java, downloads the server jar, accepts the EULA, and sets up systemd so the server comes back after a reboot. For the demo you just run the scripts. No AWS Console, no `user_data`, and no typing ssh yourself.

### Steps

1. Start the AWS Academy lab and set up `.aws/credentials`
2. Create the `ProjectP2` key pair
3. Run `provision.ps1` to create the EC2 instance
4. Run `configure.ps1` to install and start Minecraft
5. Test with `nmap`
6. Reboot the instance and test with `nmap` again
7. Run `destroy.ps1` when you are done

### Commands

Run these in PowerShell, one at a time.

**1. Go to the project folder:**

```powershell
cd $env:USERPROFILE\312-project-part-2
```

**2. Create the key pair:**

```powershell
aws ec2 create-key-pair --key-name ProjectP2 --query "KeyMaterial" --output text | Out-File -Encoding ascii ProjectP2.pem
```

**3. Provision the EC2 instance:**

```powershell
cd scripts
powershell -ExecutionPolicy Bypass -File .\provision.ps1
```

Save the **Public IP** and **Instance ID** from the output.

**4. Install and start Minecraft (about 3-5 minutes):**

```powershell
powershell -ExecutionPolicy Bypass -File .\configure.ps1
```

**5. Verify with nmap:**

```powershell
nmap -sV -Pn -p 25565 YOUR_PUBLIC_IP
```

Expected: `25565/tcp open` and service `minecraft`.

**6. Reboot test:**

```powershell
aws ec2 reboot-instances --instance-ids YOUR_INSTANCE_ID --region us-east-1
```

Wait 2-3 minutes, then run the nmap command again.

**7. Clean up:**

```powershell
powershell -ExecutionPolicy Bypass -File .\destroy.ps1
```

### Connect to the server

```powershell
nmap -sV -Pn -p 25565 YOUR_PUBLIC_IP
```

## Sources

- [Amazon Linux documentation (AWS)](https://docs.aws.amazon.com/linux/)
- [Amazon Linux 2023 product page (AWS)](https://aws.amazon.com/linux/amazon-linux-2023/)
- [Minecraft Java Edition server download](https://www.minecraft.net/en-us/download/server)
- [Minecraft Wiki: Setting up a Java Edition server](https://minecraft.wiki/w/Tutorial:Setting_up_a_Java_Edition_server)
- [systemd.service manual](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html)
- [Nmap reference guide](https://nmap.org/book/man.html)
- [AWS CLI EC2 command reference](https://docs.aws.amazon.com/cli/latest/reference/ec2/)
