#!/bin/bash


# 创建 config.env
createConfigEnv() {

    if [ -f "$(pwd)/config.env" ]; then
        echo "config.env exists." >&2
        return 1
    fi

    cat <<EOF > $(pwd)/config.env
# 博客类型 wordpress | typecho
# Blog type: wordpress | typecho
MY_BLOG_TYPE="typecho"

# 博客安装目录
# Blog installation directory
MY_BLOG_PARENT_DIR="/opt/myblog"

# 博客使用域名
# Blog domain name
MY_BLOG_DOMAIN="laosiji.io"

# 数据库密码
# Database password
MYSQL_PASSWORD="d123b456"

# 数据库名
# Database name
DB_NAME="myblog_db"

# 是否使用 ssl 证书
# Whether to use SSL certificate
ENABLE_SSL=false

# 证书路径
# Certificate path
SSL_CER_PATH="/tmp/ssl/domain.cer"
SSL_KEY_PATH="/tmp/ssl/domain.key"
EOF

    echo "config.env create success."

}

# 输出配置信息
echoConfigInfo() {

    echo "################################################################################"

    echo "博客的目录:        ${MY_BLOG_PARENT_DIR}"
    echo "博客的类型:        ${MY_BLOG_TYPE}"
    echo "博客的域名:        ${MY_BLOG_DOMAIN}"
    echo "数据库密码:        ${MYSQL_PASSWORD}"
    echo "数据库名称:        ${DB_NAME}"

    echo "证书的路径:        ${SSL_CER_PATH}"
    echo "密钥的路径:        ${SSL_KEY_PATH}"

    echo "################################################################################"

}

# 移除容器函数
rmDockerContainer() {
    if [ "$(docker ps -a | grep myblog_nginx)" ]; then
        docker rm -f myblog_nginx
    fi
    if [ "$(docker ps -a | grep myblog_php)" ]; then
        docker rm -f myblog_php
    fi
    if [ "$(docker ps -a | grep myblog_mysql)" ]; then
        docker rm -f myblog_mysql
    fi
}


check() {
    if [ "$(uname)" == "Linux" ]; then
        # 本脚本暂时只支持 ubuntu 和 debian
        if [ ! -x "$(command -v apt-get)" ]; then
            echo 'only support ubuntu and debian' >&2
            exit 1
        fi

        # 如果 docker 不存在, 退出脚本
        if [ ! -x "$(command -v docker)" ]; then
            echo 'Error: docker is not installed.' >&2
            exit 1
        fi

        # 如果 docker-compose 不存在, 退出脚本
        if [ ! -x "$(command -v docker-compose)" ]; then
            echo 'Error: docker-compose is not installed.' >&2
            exit 1
        fi

        echo "apt-get docker docker-compose check ok. continue after 3s..."
        sleep 3
        apt-get update
        apt-get install -y curl git supervisor
    fi
}


config() {
    createConfigEnv
}

sourceEnv() {
    source $(pwd)/config.env

    echoConfigInfo

    mkdir -p ${MY_BLOG_PARENT_DIR}

    # 本地测试 (macOS)
    if [ "$(uname)" == "Darwin" ]; then
        source config.demo.env
    fi

    if [ "$(uname)" == "Darwin" ]; then
        MY_BLOG_PARENT_DIR="/tmp/blog/myblog"
    fi

    # dir
    MY_BLOG_DOCKER_DIR="${MY_BLOG_PARENT_DIR}/myblog-docker"
    MY_BLOG_SITE_DIR="${MY_BLOG_PARENT_DIR}/workdir/websites/${MY_BLOG_DOMAIN}/${MY_BLOG_TYPE}"

    # nginx conf
    MY_BLOG_NGINX_CONF="${MY_BLOG_SITE_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf"
}

# 下载 myblog-docker
downloadMyBlogDocker() {

    cd ${MY_BLOG_PARENT_DIR}

    git clone https://github.com/laosiji-io/myblog-docker.git
}

copyConfig() {
    # nginx conf
    cp ${MY_BLOG_DOCKER_DIR}/conf/nginx/00-default.conf     ${MY_BLOG_DOCKER_DIR}/conf/nginx/sites-enabled/00-default.conf
    cp ${MY_BLOG_DOCKER_DIR}/conf/nginx/01-blog.conf        ${MY_BLOG_NGINX_CONF}
}

replaceNginxConfBlog() {
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

        echo ""                                             ${MY_BLOG_NGINX_CONF}
        echo "server {"                                     ${MY_BLOG_NGINX_CONF}
        echo "    listen 80;"                               ${MY_BLOG_NGINX_CONF}
        echo "    listen [::]:80;"                          ${MY_BLOG_NGINX_CONF}
        echo ""                                             ${MY_BLOG_NGINX_CONF}
        echo "    server_name ${MY_BLOG_DOMAIN};"           ${MY_BLOG_NGINX_CONF}
        echo "    return 301 https://\$host\$request_uri;"  ${MY_BLOG_NGINX_CONF}
        echo "}"                                            ${MY_BLOG_NGINX_CONF}
    else
        echo "ssl does not exist. enabled 80."
    fi

    if [ "$(uname)" == "Darwin" ]; then
        sed -i ".bak" "s|LISTEN_PORT_REPLACE|${LISTEN_PORT_REPLACE}|g"      ${MY_BLOG_NGINX_CONF}
        sed -i ".bak" "s|SSL_CERTIFICATE_REPLACE|${SSL_CER_REPLACE}|g"      ${MY_BLOG_NGINX_CONF}
        sed -i ".bak" "s|SSL_CERTIFICATE_KEY_REPLACE|${SSL_KEY_REPLACE}|g"  ${MY_BLOG_NGINX_CONF}
        sed -i ".bak" "s|SERVER_NAME_REPLACE|$MY_BLOG_DOMAIN|g"             ${MY_BLOG_NGINX_CONF}
        sed -i ".bak" "s|BLOG_TYPE_REPLACE|$MY_BLOG_TYPE|g"                 ${MY_BLOG_NGINX_CONF}

        rm -rf ${BLOG_DIR}/conf/nginx/sites-enabled/01-${MY_BLOG_DOMAIN}.conf.bak

    else
        sed -i        "s|LISTEN_PORT_REPLACE|${LISTEN_PORT_REPLACE}|g"      ${MY_BLOG_NGINX_CONF}
        sed -i        "s|SSL_CERTIFICATE_REPLACE|${SSL_CER_REPLACE}|g"      ${MY_BLOG_NGINX_CONF}
        sed -i        "s|SSL_CERTIFICATE_KEY_REPLACE|${SSL_KEY_REPLACE}|g"  ${MY_BLOG_NGINX_CONF}
        sed -i        "s|SERVER_NAME_REPLACE|$MY_BLOG_DOMAIN|g"             ${MY_BLOG_NGINX_CONF}
        sed -i        "s|BLOG_TYPE_REPLACE|$MY_BLOG_TYPE|g"                 ${MY_BLOG_NGINX_CONF}

    fi
}

replaceDockerComposeYml() {
    # docker-compose.yml
    cp  ${BLOG_DIR}/docker-compose.demo.yml ${BLOG_DIR}/docker-compose.yml

    if [ "$(uname)" == "Darwin" ]; then
        sed -i ".bak" "s|MYSQL_ROOT_PASSWORD_REPLACE|$MYSQL_PASSWORD|g"     ${BLOG_DIR}/docker-compose.yml

        rm -rf ${BLOG_DIR}/docker-compose.yml.bak
    else
        sed -i        "s|MYSQL_ROOT_PASSWORD_REPLACE|$MYSQL_PASSWORD|g"     ${BLOG_DIR}/docker-compose.yml
    fi
}

downloadTypechoCode() {
    cd ${BLOG_DIR}/workdir/websites/${MY_BLOG_DOMAIN}
    wget -N https://github.com/typecho/typecho/archive/refs/tags/v1.2.1.tar.gz
    tar zxf v1.2.1.tar.gz
    mv typecho-1.2.1 ${MY_BLOG_TYPE}
}

downloadWordpressCode() {
    cd ${BLOG_DIR}/workdir/websites/${MY_BLOG_DOMAIN}
    wget -N https://github.com/WordPress/WordPress/archive/refs/tags/6.2.2.tar.gz
    tar zxf 6.2.2.tar.gz
    mv WordPress-6.2.2 ${MY_BLOG_TYPE}
}

downBlogCode() {
    # typecho
    if [ "${MY_BLOG_TYPE}" == "typecho" ]; then
        downloadTypechoCode
    fi

    # wordpress
    if [ "${MY_BLOG_TYPE}" == "wordpress" ]; then
        downloadWordpressCode
    fi
}

dockerComposeUp() {
    # docker-compose up
    cd ${MY_BLOG_DOCKER_DIR}

    docker-compose up -d --build

    # 等待 MySQL 容器启动
    echo "Waiting for MySQL container to start..."
    sleep 3
    # until docker exec -i djk01_mysql mysqladmin ping --silent &> /dev/null; do
    until docker exec -i myblog_mysql mysql -uroot -p${MYSQL_PASSWORD} -e "SELECT 1;" &> /dev/null; do
        echo "MySQL container is not ready yet. Waiting..."
        sleep 1
    done
    echo "create mysql success. continue after 3s..."
    sleep 3
}

createDB() {
    # 创建数据库
    echo "Creating database..."
    if docker exec -i myblog_mysql mysql -uroot -p${MYSQL_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"; then
        echo "Database '${DB_NAME} created successfully."
    else
        echo "Failed to create database ${DB_NAME}."
        exit 1
    fi
}

install() {
    check
    sourceEnv
    downloadMyBlogDocker
    copyConfig
    replaceNginxConfBlog
    replaceDockerComposeYml
    downBlogCode
    dockerComposeUp
    createDB
}

uninstall() {
    rmDockerContainer

    if [ "$(uname)" == "Linux" ]; then
        rmLaravelWorker
    fi
    echo "uninstall success."
}


# 根据参数执行函数
case "$1" in
    config)
        config
        ;;
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    *)
        echo "Usage: "
        echo ""
        echo "bash $0 { config | install | uninstall }"
        echo ""

        exit 1
esac


exit 0

