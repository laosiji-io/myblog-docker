#!/bin/bash

source config.env

if [ "$(uname)" == "Darwin" ]; then
    MY_BLOG_DIR="/tmp/myblog"
fi

# echo $MY_BLOG_TYPE
# echo $MY_BLOG_DIR
# echo $MY_BLOG_DOMAIN
# echo $MYSQL_PASSWORD
# echo $DB_NAME
# echo $ENABLE_SSL
# echo $SSL_CER_PATH
# echo $SSL_KEY_PATH

cd ${MY_BLOG_DIR}

rm -rf ${MY_BLOG_TYPE}-docker

git clone https://github.com/mangozz123/myblog-docker.git

mv myblog-docker ${MY_BLOG_TYPE}-docker

BLOG_DIR=${MY_BLOG_DIR}/${MY_BLOG_TYPE}-docker

cd $BLOG_DIR

# nginx conf
cp ${BLOG_DIR}/conf/nginx/00-default.conf ${BLOG_DIR}/conf/nginx/sites-enabled/00-default.conf
cp ${BLOG_DIR}/conf/nginx/01-blog.conf ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf

LISTEN_PORT_REPLACE=80
SSL_CER_REPLACE=""
SSL_KEY_REPLACE=""

# 如果 ENABLE_SSL 为 true 判断 SSL_CER_PATH SSL_KEY_PATH 文件是否存在
if [ $ENABLE_SSL = true ]; then
    if [ ! -f $SSL_CER_PATH ]; then
        echo "$SSL_CER_PATH 文件不存在"
        exit 1
    fi
    if [ ! -f $SSL_KEY_PATH ]; then
        echo "$SSL_KEY_PATH 文件不存在"
        exit 1
    fi

    echo "ssl exists. enabled 443 and ssl."

    mkdir -p ${BLOG_DIR}/workdir/ssl/${MY_BLOG_DOMAIN}

    cp ${SSL_CER_PATH}  ${BLOG_DIR}/workdir/ssl/${MY_BLOG_DOMAIN}/ssl.cer
    cp ${SSL_KEY_PATH}  ${BLOG_DIR}/workdir/ssl/${MY_BLOG_DOMAIN}/ssl.key

    LISTEN_PORT_REPLACE="443 ssl"
    SSL_CER_REPLACE="ssl_certificate     /workdir/ssl/${MY_BLOG_DOMAIN}/ssl.cer;"
    SSL_KEY_REPLACE="ssl_certificate_key /workdir/ssl/${MY_BLOG_DOMAIN}/ssl.key;"

    echo ""                                             >> ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf
    echo "server {"                                     >> ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf
    echo "    listen 80;"                               >> ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf
    echo "    listen [::]:80;"                          >> ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf
    echo ""                                             >> ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf
    echo "    server_name ${MY_BLOG_DOMAIN};"           >> ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf
    echo "    return 301 https://\$host\$request_uri;"  >> ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf
    echo "}"                                            >> ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf
else
    echo "ssl does not exist. enabled 80."
fi

if [ "$(uname)" == "Darwin" ]; then
    sed -i ".bak" "s|LISTEN_PORT_REPLACE|${LISTEN_PORT_REPLACE}|g"      ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf
    sed -i ".bak" "s|SSL_CERTIFICATE_REPLACE|${SSL_CER_REPLACE}|g"      ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf
    sed -i ".bak" "s|SSL_CERTIFICATE_KEY_REPLACE|${SSL_KEY_REPLACE}|g"  ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf
    sed -i ".bak" "s|SERVER_NAME_REPLACE|$MY_BLOG_DOMAIN|g"             ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf
    sed -i ".bak" "s|BLOG_TYPE_REPLACE|$MY_BLOG_TYPE|g"                 ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf

    rm -rf ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf.bak

else
    sed -i        "s|LISTEN_PORT_REPLACE|${LISTEN_PORT_REPLACE}|g"      ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf
    sed -i        "s|SSL_CERTIFICATE_REPLACE|${SSL_CER_REPLACE}|g"      ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf
    sed -i        "s|SSL_CERTIFICATE_KEY_REPLACE|${SSL_KEY_REPLACE}|g"  ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf
    sed -i        "s|SERVER_NAME_REPLACE|$MY_BLOG_DOMAIN|g"             ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf
    sed -i        "s|BLOG_TYPE_REPLACE|$MY_BLOG_TYPE|g"                 ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf

fi


# docker-compose.yml
cp  ${BLOG_DIR}/docker-compose.demo.yml ${BLOG_DIR}/docker-compose.yml

if [ "$(uname)" == "Darwin" ]; then
    sed -i ".bak" "s|MYSQL_ROOT_PASSWORD_REPLACE|$MYSQL_PASSWORD|g"     ${BLOG_DIR}/docker-compose.yml

    rm -rf ${BLOG_DIR}/docker-compose.yml.bak
else
    sed -i        "s|MYSQL_ROOT_PASSWORD_REPLACE|$MYSQL_PASSWORD|g"     ${BLOG_DIR}/docker-compose.yml
fi

# typecho
if [ "${MY_BLOG_TYPE}" == "typecho" ]; then
    mkdir -p ${BLOG_DIR}/workdir/websites/${MY_BLOG_DOMAIN}
    cd ${BLOG_DIR}/workdir/websites/${MY_BLOG_DOMAIN}
    wget -N https://github.com/typecho/typecho/archive/refs/tags/v1.2.1.tar.gz
    tar zxf v1.2.1.tar.gz
    mv typecho-1.2.1 ${MY_BLOG_TYPE}
fi

# wordpress
if [ "${MY_BLOG_TYPE}" == "wordpress" ]; then
    mkdir -p ${BLOG_DIR}/workdir/websites/${MY_BLOG_DOMAIN}
    cd ${BLOG_DIR}/workdir/websites/${MY_BLOG_DOMAIN}
    wget -N https://github.com/WordPress/WordPress/archive/refs/tags/6.2.2.tar.gz
    tar zxf 6.2.2.tar.gz
    mv WordPress-6.2.2 ${MY_BLOG_TYPE}
fi

# Disallow all User-agent
# echo "User-agent: *" >  ${BLOG_DIR}/workdir/websites/${MY_BLOG_DOMAIN}/${MY_BLOG_TYPE}/robots.txt
# echo "Disallow: /"   >> ${BLOG_DIR}/workdir/websites/${MY_BLOG_DOMAIN}/${MY_BLOG_TYPE}/robots.txt

# docker run 
cd ${BLOG_DIR}

docker rm -f myblog_nginx
docker rm -f myblog_php
docker rm -f myblog_mysql

sleep 1
docker-compose up -d
sleep 1

# 等待 MySQL 容器启动
echo "Waiting for MySQL container to start..."
sleep 3

# until docker exec -i myblog_mysql mysqladmin ping --silent &> /dev/null; do
until docker exec -i myblog_mysql mysql -uroot -p${MYSQL_PASSWORD} -e "SELECT 1;" &> /dev/null; do
    echo "MySQL container is not ready yet. Waiting..."
    sleep 1
done

# 创建数据库
echo "Creating database..."
if docker exec -i myblog_mysql mysql -uroot -p${MYSQL_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"; then
    echo "Database '${DB_NAME} created successfully."
else
    echo "Failed to create database ${DB_NAME}."
    exit 1
fi

exit 0

