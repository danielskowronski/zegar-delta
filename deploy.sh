#!/bin/bash
echo "installing requirements"
bundle install

echo "killing pwm"
ruby test-tools/disable.rb

echo "trying to stop daemons"
systemctl stop zd-minion
systemctl stop zd-webgui

echo "killing pwm (SIGTERM exception could have fired)"
ruby test-tools/disable.rb

echo "trying to trying to back up alarms.json"
mv /opt/zd/minion/alarms.json  /tmp/alarms.json.prev

echo "trying to trying to remove old version"
rm -Rf /opt/zd/*
mkdir -p /opt/zd/minion
mkdir -p /opt/zd/webgui

echo "deploying new version"
cp -r minion/* /opt/zd/minion/
cp /tmp/alarms.json.prev /opt/zd/minion/alarms.json
cp -r webgui/* /opt/zd/webgui/

echo "installing daemons"
cp *.service /etc/systemd/system/
systemctl daemon-reload
setcap 'cap_net_bind_service=+ep' /usr/local/bin/rackup

echo "starting daemons"
systemctl start zd-minion
systemctl start zd-webgui
systemctl enable zd-webgui
systemctl enable zd-minion
