#!/bin/sh

# Mock systemD environment for the installer
if ! command -v systemctl >/dev/null 2>&1; then
    echo '#!/bin/sh' > /usr/bin/systemctl
    echo 'echo "ActiveState=active"' >> /usr/bin/systemctl
    echo 'exit 0' >> /usr/bin/systemctl
    chmod +x /usr/bin/systemctl
fi
mkdir -p /run/systemd/system

# Mock 'ps' to trick the installer check for PID 1 process name
if [ -f /bin/ps ] && [ ! -f /bin/ps.original ]; then
    mv /bin/ps /bin/ps.original
    echo '#!/bin/sh' > /bin/ps
    echo 'if [ "$*" = "--no-headers -o comm 1" ]; then' >> /bin/ps
    echo '  echo "systemd"' >> /bin/ps
    echo 'else' >> /bin/ps
    echo '  /bin/ps.original "$@"' >> /bin/ps
    echo 'fi' >> /bin/ps
    chmod +x /bin/ps
fi

# Mock 'file' command to trick the installer check for SystemD and Architecture
# The installer runs 'file -L /sbin/init'. We provide a fake output that satisfies both:
# 1. It looks like a systemd binary (path)
# 2. It contains "x86-64" for the architecture check
if [ -f /usr/bin/file ] && [ ! -f /usr/bin/file.original ]; then
    mv /usr/bin/file /usr/bin/file.original
    echo '#!/bin/sh' > /usr/bin/file
    echo 'args="$@"' >> /usr/bin/file
    echo 'if echo "$args" | grep -q "/sbin/init"; then' >> /usr/bin/file
    echo '  echo "/lib/systemd/systemd: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, for GNU/Linux 3.2.0, BuildID[sha1]=xxx, stripped"' >> /usr/bin/file
    echo 'else' >> /usr/bin/file
    echo '  /usr/bin/file.original "$@"' >> /usr/bin/file
    echo 'fi' >> /usr/bin/file
    chmod +x /usr/bin/file
fi

# Ensure postgres user exists for the embedded database installer
if ! id "postgres" >/dev/null 2>&1; then
    adduser --system --group --home /var/lib/postgresql postgres
fi

# Verifica se a instalação já foi realizada (check for standalone.sh to ensure completion)
if [ ! -f "/opt/e-SUS/webserver/standalone.sh" ]; then
    echo "Instalando e-SUS AB..."
    # Clean up previous failed attempts
    rm -rf /opt/e-SUS/database
    rm -rf /opt/e-SUS/jre
    rm -rf /opt/e-SUS/webserver
    
    cd /home/downloads || exit
    
    # Executa a instalação
    echo "s" | java -jar eSUS-AB-PEC.jar -console -url="${APP_DB_URL}" -username="${APP_DB_USER}" -password="${APP_DB_PASSWORD}" -treinamento
    
    if [ ! -f "/opt/e-SUS/migrador.jar" ]; then
        echo "Extraindo migrador.jar..."
        jar xf eSUS-AB-PEC.jar container/database/migrador.jar
        if [ -f "container/database/migrador.jar" ]; then
             mkdir -p /opt/e-SUS
             cp container/database/migrador.jar /opt/e-SUS/
        fi
    fi
fi

file="/opt/e-SUS/webserver/config/application.properties"

if [ -f "$file" ]; then
    while IFS='=' read -r key value
    do
        key=$(echo "$key" | xargs | tr '.' '_')
        value=$(echo "$value" | xargs)
        if [ ${#key} -le 0 ]; then
          continue
        fi
        export "${key}"="${value}"
    done < "$file"
fi

if [ ! -z "$APP_DB_URL" ]; then
    export spring_datasource_url=$APP_DB_URL
fi
if [ ! -z "$APP_DB_USER" ]; then
    export spring_datasource_username=$APP_DB_USER
fi
if [ ! -z "$APP_DB_PASSWORD" ]; then
    export spring_datasource_password=$APP_DB_PASSWORD
fi

echo "Database URL = " ${spring_datasource_url}
echo "Username = " ${spring_datasource_username}
echo "Password = " ${spring_datasource_password}

java -jar /opt/e-SUS/migrador.jar -url=${spring_datasource_url} -username=${spring_datasource_username} -password=${spring_datasource_password}
sh /opt/e-SUS/webserver/standalone.sh