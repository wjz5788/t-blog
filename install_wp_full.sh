#!/bin/bash
set -e

# =============================
# WordPress 增强版一键安装脚本
# =============================

# ----------- 配置参数 ------------
DB_NAME="myblog_db"
DB_USER="myblog_user"
DB_PASS="ChangeMe123!"
WP_DIR="/var/www/myblog"
DOMAIN="wjz5788.com"
# --------------------------------

echo "1️⃣ 更新系统..."
sudo apt update -y && sudo apt upgrade -y

echo "2️⃣ 安装必要组件..."
sudo apt install -y nginx php8.1-fpm php8.1-mysql php8.1-cli php8.1-curl \
php8.1-gd php8.1-mbstring php8.1-xml php8.1-xmlrpc php8.1-soap php8.1-intl \
php8.1-zip mariadb-server unzip curl wget

echo "3️⃣ 启动服务..."
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl enable php8.1-fpm
sudo systemctl start php8.1-fpm
sudo systemctl enable mariadb
sudo systemctl start mariadb

echo "4️⃣ 配置防火墙..."
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable

# -------- 创建数据库 --------
echo "5️⃣ 配置 MariaDB 数据库..."
sudo mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# -------- 下载 WordPress --------
echo "6️⃣ 下载 WordPress..."
if [ ! -d "$WP_DIR" ]; then
    sudo mkdir -p "$WP_DIR"
fi

TMP_DIR="/tmp/wordpress"
rm -rf $TMP_DIR
mkdir -p $TMP_DIR
curl -O https://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz -C $TMP_DIR --strip-components=1
sudo mv $TMP_DIR/* $WP_DIR/
sudo chown -R www-data:www-data $WP_DIR
sudo chmod -R 755 $WP_DIR

# -------- 配置 wp-config.php --------
echo "7️⃣ 配置 wp-config.php..."
sudo cp $WP_DIR/wp-config-sample.php $WP_DIR/wp-config.php
sudo sed -i "s/database_name_here/$DB_NAME/" $WP_DIR/wp-config.php
sudo sed -i "s/username_here/$DB_USER/" $WP_DIR/wp-config.php
sudo sed -i "s/password_here/$DB_PASS/" $WP_DIR/wp-config.php

# -------- 配置 Nginx --------
NGINX_CONF="/etc/nginx/sites-available/myblog"
if [ ! -f "$NGINX_CONF" ]; then
    echo "8️⃣ 配置 Nginx..."
    sudo tee $NGINX_CONF > /dev/null <<EOL
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    root $WP_DIR;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL
fi

# 启用站点
if [ ! -L /etc/nginx/sites-enabled/myblog ]; then
    sudo ln -s /etc/nginx/sites-available/myblog /etc/nginx/sites-enabled/
fi
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

# -------- 安装插件 --------
echo "9️⃣ 安装 Relevanssi 和 WP WordCloud 插件..."
PLUGIN_DIR="$WP_DIR/wp-content/plugins"
sudo -u www-data wp core download --path=$WP_DIR
sudo -u www-data wp plugin install relevanssi --activate --path=$WP_DIR
sudo -u www-data wp plugin install wp-wordcloud --activate --path=$WP_DIR

echo "=============================="
echo "WordPress 安装完成！"
echo "访问 http://$DOMAIN 来完成安装向导"
echo "数据库：$DB_NAME / 用户：$DB_USER / 密码：$DB_PASS"
echo "已安装插件：Relevanssi（全文搜索）、WP WordCloud（词云）"
echo "=============================="
