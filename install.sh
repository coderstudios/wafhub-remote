#!/bin/bash

{
    
while getopts k: flag
do
    case "${flag}" in
        k) APIKEY=${OPTARG};;
    esac
done

if [ -z "$APIKEY" ]; then
    echo "No API key provided, your API key can be found in your https://wafhub.com account."
    exit 0;
fi

cat <<EOF > /srv/wafhub-remote/run.sh
#!/bin/bash

allLogFiles () {
    LOGFILES=/var/log/nginx/*

    for f in \$LOGFILES
    do
        filesize=\$(stat -c%s "\$f")
        if [ \$filesize ]; then
            curl https://wafhub.com/api/logs -H "Authorization: Bearer $APIKEY" -F "web=nginx" -F "host=$HOSTNAME" -F "log=@\$f"
        fi
        sleep 10s
    done

    LOGFILES=/var/log/apache2/*
    for f in \$LOGFILES
    do
        filesize=\$(stat -c%s "\$f")
        if [ \$filesize ]; then
            curl https://wafhub.com/api/logs -H "Authorization: Bearer $APIKEY" -F "web=apache" -F "host=$HOSTNAME" -F "log=@\$f"
        fi

        sleep 10s
    done
    unset \$LOGFILES
}

allLogFiles

EOF

cat <<EOF > /srv/wafhub-remote/wafhub.service
[Unit]
Description=WAFHUB Log Service

[Service]
User=root
Type=simple
TimeoutSec=0
PIDFile=/run/wafhub.pid
ExecStart=/bin/bash /srv/wafhub-remote/run.sh > /dev/null 2>/dev/null
ExecStop=/bin/kill -HUP \$MAINPID
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process

Restart=on-failure
RestartSec=42s

StandardOutput=null
StandardError=null
[Install]
WantedBy=default.target
EOF

sudo rm /etc/systemd/system/wafhub.service
sudo ln -s /srv/wafhub-remote/wafhub.service /etc/systemd/system/wafhub.service

sudo systemctl daemon-reload
sudo systemctl start wafhub

}
