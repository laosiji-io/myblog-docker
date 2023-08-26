# myblog-docker
build wordpress or typecho by docker-compose

> Typecho是一款轻量高效的博客系统。原生支持 Markdown 排版语法，易读更易写。实现了完整的插件与模板机制。超低的 CPU 和内存使用率，足以发挥主机的最高性能。本博客就是使用docker-compose安装的Typecho。

## 下载安装脚本

```shell
mkdir /root/install-myblog
cd /root/install-myblog
wget https://raw.githubusercontent.com/laosiji-io/myblog-docker/master/install.sh
```

## 生成配置文件
```shell
bash install.sh config
```

> 会在当前目录生成一个 config.env 的配置文件

```shell
MY_BLOG_TYPE="typecho"              # 选择博客类型 支持 typecho 和 wordpress
MY_BLOG_DIR="/opt/myblog"           # 博客默认安装的父级目录 /opt/myblog
MY_BLOG_DOMAIN="laosiji.io"         # 博客域名
MYSQL_PASSWORD="d123b456"           # 数据库密码
DB_NAME="myblog_db"                 # 数据库名称

ENABLE_SSL=false                    # 是否启用 SSL
SSL_CER_PATH="/tmp/ssl/domain.cer"  # SSL 证书路径
SSL_KEY_PATH="/tmp/ssl/domain.key"  # SSL 证书密钥路径
```
### 修改配置文件

> 主要修改以下三个参数, 其他的可以暂时不改, 如果使用 cloudflare 无需证书
```shell
MY_BLOG_DOMAIN="laosiji.io"         # 博客域名
MYSQL_PASSWORD="d123b456"           # 数据库密码
DB_NAME="myblog_db"                 # 数据库名称
```

## 执行安装命令, 安装完毕后会自动启动容器

```shell
bash install.sh install
```
