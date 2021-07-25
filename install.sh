#!/bin/bash
#
# Setup Raspberry Pi OS on a pi zero for clock display
# Run logged in as default pi account over ssh from headless wifi

set -e

sudo apt-get update
sudo apt-get install -y vim htop xorg openbox chromium-browser xserver-xorg xinit unclutter lighttpd lsof git iotop

# Make a bit more space and stop extraneous services
sudo systemctl stop dphys-swapfile.service
sudo systemctl disable dphys-swapfile.service
sudo dphys-swapfile uninstall

sudo systemctl stop bluetooth
sudo systemctl disable bluetooth

sudo systemctl stop hciuart
sudo systemctl disable hciuart

sudo systemctl stop avahi-daemon
sudo systemctl disable avahi-daemon

sudo systemctl stop avahi-daemon.socket
sudo systemctl disable avahi-daemon.socket

sudo systemctl stop apt-daily-upgrade.timer
sudo systemctl disable apt-daily-upgrade.timer

sudo systemctl stop apt-daily.timer
sudo systemctl disable apt-daily.timer

sudo systemctl stop man-db.timer
sudo systemctl disable man-db.timer

# Disable journaling? need to do from another O/S because we need to tune tune2fs on unmounted or r/o filesystem

# Use < < - do avoid escaping $vars
cat > ~/.xserverrc <<-EOF
#!/bin/sh
#Start an X server with power management disabled so that the screen never goes blank.
exec /usr/bin/X -s 0 -dpms -nolisten tcp "$@"
EOF

cat > ~/.xsession <<-EOF
#!/bin/sh
#This tells X server to start Chromium at startup
chromium-browser --start-fullscreen --window-size=1920,1080 --disable-infobars --noerrdialogs --incognito --kiosk http://localhost
EOF

sudo tee /etc/systemd/system/clock.service > /dev/null <<EOF
[Unit]
Description=Clock
After=network-online.target
DefaultDependencies=no

[Service]
User=pi
ExecStart=/usr/bin/startx
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable clock
sudo systemctl restart clock

sudo timedatectl set-timezone Australia/Adelaide

test -e log2zram/.git|| git clone https://github.com/StuartIanNaylor/log2zram
pushd log2zram
sudo sh ./install.sh
popd
#sudo sed -i /etc/log2zram.con -e '/SIZE=/ s/SIZE=.*/SIZE=32M/'

# rm -rf /var/cache/lighttpd <— mount this in ram instead
rm -rf /var/backups

grep -q /tmp /etc/fstab || echo 'tmpfs /tmp tmpfs defaults,noatime 0 0' >> /etc/fstab
grep -q /var/cache/lighttpd || echo 'tmpfs /var/cache/lighttpd tmpfs defaults,noatime 0 0' >> /etc/fstab

# TODO - work out how to mount rest of system ro
# Writes after boot include
# ~/.xsession-errors, possibly ~/.config/chromium…
# ~/.Xauthority

sudo tee /var/www/html/index.html > /dev/null <<EOF
<!DOCTYPE html>
<html style="margin:0; padding:0; height:100%">
  <head>
    <title>PiZero HDMI Clock</title>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
    <meta charset="utf-8">
    <style type="text/css">
      html {
        margin: 0;
        pading: 0;
        background: #010e19;
        font-family: sans-serif;
        font-weight: normal;
        height: 100%;
        color: green
      }
      body {
        margin: 0;
        padding: 0;
        display: flex;
        align-items: center;
        justify-content: center;
        height: 100%;
      }
      .myfont {
        font-kerning: none;
      }
    </style>
    <script type="text/javascript">
      "use strict";
      function hour(h) {
        if (h >= 10) { return h + ""; }
        return "0" + h;
      }
      function bootstrap() {
        var eTime = document.getElementById("text-time");
        var eDate = document.getElementById("text-date");
        function textSizer() {
          var sFont = 20;
          for (var r = 0; r < 3; r++) {
            sFont *= 0.8 / (eTime.offsetWidth / eTime.parentNode.parentNode.offsetWidth);
            eTime.style.fontSize = sFont + "pt";
          }
          eDate.style.fontSize = (sFont / 2) + "pt";
        }
        function clockTimer() {
          var now = new Date();
          var txt = "" + h(d.getHours()) + ":" + h(d.getMinutes()) + ":" + h(d.getSeconds());
          eTime.textContent = txt;
          eDate.textContent = now.dateToString();
          setTimeout(clockTimer, 1050 - d.getTime() % 1000);
        }
        clockTimer();
	textSizer();
      }
      window.addEventListener("resize", textSizer);
      window.addEventListenet("load", bootstrap);
    </script>
  </head>
  <body>
    <span>
      <span id="text-time" class="myfont""></span>
      <br/>
      <div id="text-date" class="myfont"></div>
    </span>
  </body>
</html>
EOF

# TODO: Disable chromium searching for updates...
