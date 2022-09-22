set -e
VERS_NODE=16
VERS_JAVA=17

# bzip2 gnupg2
PKGS="ca-certificates openjdk-${VERS_JAVA:-17}-jdk sudo unzip wget jq curl nodejs google-chrome-stable"

PKGS_X11="xvfb x11vnc pulseaudio fluxbox libfontconfig libfreetype6 xfonts-cyrillic xfonts-scalable fonts-liberation fonts-ipafont-gothic fonts-wqy-zenhei fonts-tlwg-loma-otf ttf-ubuntu-font-family fonts-noto-color-emoji"
PKGS_TOOLS="iputils-ping psmisc lsof vim net-tools"

installSystemPackages() {
  echo "Preparing Package Repos ... "
  wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - 
  echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list
  curl -sL https://deb.nodesource.com/setup_${VERS_NODE}.x | sudo bash - >/dev/null
  PKGS=${1:-$PKGS}
  echo "Updating apt database ... "
  apt-get -qqy update
  echo "Installing Packages " $PKGS ...
  apt-get -qqy --no-install-recommends install $PKGS
}

patchChrome() {
  echo "Patching Chrome with --no-sandbox flag"
  F=`readlink -f /usr/bin/google-chrome`
  [ -n "$F" ] && mv $F $F-base && touch $F && chmod +x $F && cat > $F <<EOF
#!/bin/bash
umask 002
exec -a "\$0" "$F-base" --no-sandbox "\$@"
EOF
}

installChromeDriver() {
  echo "Installing ChromeDriver ... "
  C=`google-chrome --version | sed -E "s/.* ([0-9]+)(\.[0-9]+){3}.*/\1/"`
  P=`wget --no-verbose -O - "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_$C" 2>/dev/null`
  [ -z "$P" ] && C=`expr $C -1` && P=`wget --no-verbose -O - "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_$C" 2>/dev/null`
  wget --no-verbose -O /tmp/chromedriver_linux64.zip https://chromedriver.storage.googleapis.com/$P/chromedriver_linux64.zip
  unzip -o /tmp/chromedriver_linux64.zip -d /opt/selenium
  rm -f /usr/bin/chromedriver
  ln -s /opt/selenium/chromedriver /usr/bin
  rm /tmp/chromedriver_linux64.zip
  echo "chrome" > /opt/selenium/browser_name
}

installMaven() {
  echo "Installing Maven ... "
  URL=`wget -q -O - https://maven.apache.org/download.cgi  | grep binaries | grep 'bin.tar.gz</a>' | cut -d '"' -f2`
  wget -q -nv -O - "$URL" | tar xzf - -C /opt
  perl -pi -e 's,PATH=,PATH='`ls -1d /opt/*/bin | tr "\n" ":"`',g'  /etc/environment
}

installSeleniumServer() {
  echo "Installing Selenium Server ... "
  wget --no-verbose https://github.com/SeleniumHQ/selenium/releases/download/selenium-4.4.0/selenium-server-4.4.0.jar \
      -O /opt/selenium/selenium-server.jar
}

installAndStartSeleniumStandalone() {
  echo "Installing and Staring Selenium Standalone ... "
  npm install -g selenium-standalone
  selenium-standalone install
  nohup selenium-standalone start >/tmp/selenium-standalone.log 2>&1 &
}

startX11() {
  echo "Starging X11 Server"
  [ ! -f /usr/bin/Xvfb ] && return 1
  mkdir -p /tmp/.X11-unix && sudo chmod 1777 /tmp/.X11-unix
  if [ -f /usr/bin/fluxbox ]; then
    nohup xvfb-run --server-num=99 --listen-tcp \
        --server-args="-screen 0 1369x1020x24 -fbdir /var/tmp -dpi 96 -listen tcp -noreset -ac +extension RANDR" \
        /usr/bin/fluxbox -display :99.0 >/tmp/Xvfb.log 2>&1 & 
  else
    nohup Xvfb -ac :99.0 >/tmp/Xvfb.log 2>&1 &
  fi
  echo "DISPLAY=:99.0" >> /etc/environment
  [ -f /usr/bin/x11vnc ] && nohup x11vnc  -forever -shared -rfbport 5900 -rfbportv6 5900 -display :99.0 >/tmp/x11vnc.log 2>&1 &
  [ -d /opt/bin/noVNC ] && nohup /opt/bin/noVNC/utils/launch.sh --listen 7900 --vnc localhost:5900 >/tmp/novnc.log 2>&1 &
}

downloadNoVNC() {
  NOVNC_SHA="84f102d6a9ffaf3972693d59bad5c6fddb6d7fb0"
  WEBSOCKIFY_SHA="c5d365dd1dbfee89881f1c1c02a2ac64838d645f"
  mkdir -p /opt/bin
  wget -q -nv -O noVNC.zip \
        "https://github.com/novnc/noVNC/archive/${NOVNC_SHA}.zip" \
    && unzip -x noVNC.zip \
    && mv noVNC-${NOVNC_SHA} /opt/bin/noVNC \
    && cp /opt/bin/noVNC/vnc.html /opt/bin/noVNC/index.html \
    && rm noVNC.zip \
    && wget -nv -O websockify.zip \
        "https://github.com/novnc/websockify/archive/${WEBSOCKIFY_SHA}.zip" \
    && unzip -x websockify.zip \
    && rm websockify.zip \
    && rm -rf websockify-${WEBSOCKIFY_SHA}/tests \
    && mv websockify-${WEBSOCKIFY_SHA} /opt/bin/noVNC/utils/websockify
}

while [ -n "$1" ]; do
  case $1 in
    --with-x11) X11=true; PKGS="$PKGS $PKGS_X11";;
    --with-hub) HUB=true;;
    --with-side) SIDE=true;;
    --with-vnc) VNC=true;;
  esac
  shift
done

installSystemPackages "$PKGS"
[ -n "$SIDE" ] && installSeleniumIDE
[ -n "$X11" -a -n "$VNC" ] && downloadNoVNC
[ -n "$X11" ] && startX11
[ -n "$HUB" ] && installAndStartSeleniumStandalone
installMaven
patchChrome

