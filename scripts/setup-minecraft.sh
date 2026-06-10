#!/bin/bash
# Server-side Minecraft setup (run on Amazon Linux 2023 via configure.ps1)
# Ref: https://minecraft.wiki/w/Tutorial:Setting_up_a_Java_Edition_server
set -euo pipefail

# Java 25 is required for current Minecraft server jars.
# Do not install the full curl package; AL2023 already has curl-minimal and dnf will conflict.
# Ref: https://docs.aws.amazon.com/corretto/latest/corretto-25-ug/amazon-linux-install.html
sudo dnf install -y java-25-amazon-corretto-headless wget python3

sudo mkdir -p /opt/minecraft
cd /opt/minecraft

if [ ! -s server.jar ]; then
  # Download the latest release server.jar from Mojang's version manifest API.
  # Ref: https://minecraft.wiki/w/Tutorial:Setting_up_a_Java_Edition_server
  MANIFEST=$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json)
  VERSION=$(echo "$MANIFEST" | python3 -c "import sys,json; print(json.load(sys.stdin)['latest']['release'])")
  META_URL=$(echo "$MANIFEST" | python3 -c "import sys,json; m=json.load(sys.stdin); v='$VERSION'; print(next(x['url'] for x in m['versions'] if x['id']==v))")
  DL=$(curl -s "$META_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['downloads']['server']['url'])")
  sudo curl -f -o server.jar "$DL"
fi

# First run creates eula.txt and server.properties, then stops because eula=false.
# Ref: https://minecraft.wiki/w/Server.properties#eula
if [ ! -f eula.txt ] || [ ! -f server.properties ]; then
  cd /opt/minecraft
  # -Xms1G -Xmx1536M fits t3.small (2 GB RAM). || true because exit on EULA is expected.
  sudo java -Xms1G -Xmx1536M -jar server.jar nogui || true
  sleep 5
fi

if [ -f eula.txt ]; then
  sudo sed -i 's/eula=false/eula=true/' eula.txt
else
  echo "eula=true" | sudo tee eula.txt > /dev/null
fi

# Run the server as a dedicated user, not root.
sudo useradd -r -s /sbin/nologin minecraft 2>/dev/null || true
sudo chown -R minecraft:minecraft /opt/minecraft

# systemd keeps the server running after reboot.
# KillSignal=SIGINT gives Java a clean shutdown (fixes the Part 1 stop issue).
# Ref: https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html
sudo tee /etc/systemd/system/minecraft.service > /dev/null <<'EOF'
[Unit]
Description=Minecraft Server
After=network.target

[Service]
User=minecraft
WorkingDirectory=/opt/minecraft
ExecStart=/usr/bin/java -Xms1G -Xmx1536M -jar /opt/minecraft/server.jar nogui
Restart=on-failure
KillSignal=SIGINT
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable minecraft
sudo systemctl restart minecraft

echo "Waiting for Minecraft to listen on 25565..."
for i in $(seq 1 30); do
  if sudo ss -tln | grep -q ':25565'; then
    echo "Minecraft is listening on port 25565."
    break
  fi
  sleep 10
done

sudo systemctl status minecraft --no-pager || true
