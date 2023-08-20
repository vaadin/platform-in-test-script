set -e

[ `id -u` = 0 ] || exit 1
type apt-get 2>/dev/null || exit 2

# bzip2 gnupg2
PKGS="ca-certificates sudo unzip wget jq curl"
PKGS_X11="xvfb x11vnc pulseaudio fluxbox libfontconfig libfreetype6 xfonts-cyrillic xfonts-scalable fonts-liberation fonts-ipafont-gothic fonts-wqy-zenhei fonts-tlwg-loma-otf ttf-ubuntu-font-family fonts-noto-color-emoji"
PKGS_TOOLS="iputils-ping psmisc lsof vim net-tools"
PKGS_LIB="libgconf-2-4 libatk1.0-0 libatk-bridge2.0-0 libgdk-pixbuf2.0-0 libgtk-3-0 libgbm-dev libnss3-dev libxss-dev libasound2"

addChromeRepo() {
  echo "Adding Chrome Repo ... "
  wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - 
  echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list
}

installNode() {
  echo "Installing Node ${VERS_NODE} ... "
  curl -sL https://deb.nodesource.com/setup_${VERS_NODE}.x | sudo bash - >/dev/null
}

installSystemPackages() {
  PKGS=${1:-$PKGS}
  echo "Updating apt database ... "
  apt-get -qqy update
  echo "Installing Packages " $PKGS ...
  apt-get -qqy --no-install-recommends install $PKGS
}

patchChrome() {
  F=`readlink -f /usr/bin/google-chrome`
  [ -n "$F" -a ! -f $F-base ] && mv $F $F-base && touch $F && chmod +x $F \
    && echo "Patching Chrome with --no-sandbox flag" \
    && cat > $F <<EOF
#!/bin/bash
umask 002
echo ">>>>>>>>" >> chrome.out
ps -feaww >> chrome.out
echo "exec -a \$0 $F-base --no-sandbox \$@" >> chrome.out
exec -a "\$0" "$F-base" --no-sandbox "\$@" 2>> chrome.out
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
  [ ! -w /opt ] && return 1
  echo "Installing Maven ... "
  URL=`wget -q -O - https://maven.apache.org/download.cgi  | grep binaries | grep 'bin.tar.gz</a>' | cut -d '"' -f2`
  wget -q -nv -O - "$URL" | tar xzf - -C /opt
  ls -l /usr/bin/mvn
  rm -f /usr/bin/mvn
  ln -s /opt/*/bin/mvn /usr/bin/mvn
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

[ -z "$1" ] && args="--node --java --chrome" || args=$*

for i in $args; do
  extra=`echo "$i" | grep = | cut -d = -f2`
  case $i in
    --node*) 
      VERS_NODE=${extra:-16}
      installNode
      PKGS="$PKGS nodejs" ;;
    --java*) 
      VERS_JAVA=${extra:-17}
      installMaven
      PKGS="$PKGS openjdk-${VERS_JAVA:-17}-jdk";;
    --chrome*)
      addChromeRepo
      PKGS="$PKGS google-chrome-stable";;
    --x11) X11=true; PKGS="$PKGS $PKGS_X11";;
    --hub) HUB=true;;
    --vnc) VNC=true;;
    --lib-chrome) PKGS="$PKGS $PKGS_LIB";;
  esac
done

installSystemPackages "$PKGS"
echo "$PKGS" | grep -q chrome && patchChrome
[ -n "$X11" -a -n "$VNC" ] && downloadNoVNC
[ -n "$X11" ] && startX11
[ -n "$HUB" ] && installAndStartSeleniumStandalone
exit 0  

