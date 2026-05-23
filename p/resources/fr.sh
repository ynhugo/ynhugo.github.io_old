case $1 in
  change-repo)
    # 更换软件源
    termux-change-repo              # 选择国内的安装源
    # 根据提示输入y回车
    # 空格选中Single mirror并回车，然后空格选择mirrors.ustc.edu.cn再次回车

    # 更新并升级软件包
    pkg update && pkg upgrade -y
    ;;
  install)
    pkg install openssh git curl wget -y
    sshd  # 启动ssh服务端

    # 安装 nginx
    pkg install nginx -y
    nginx -v
    nginx
    curl -I 127.0.0.1:8080  # 能看到200状态码则说明服务器已运行

    # 安装 php-fpm
    # DVWA 是使用 PHP 编写的，而 nginx 服务器本身并不处理 php 文件，它会把 php 文件的请求转发给 php-fpm 处理，然后将处理结果返回给客户端。因此需要再安装 php-fpm:
    pkg install php-fpm -y
    php-fpm -v
    # 改配置
    cp $PREFIX/etc/php-fpm.d/www.conf $PREFIX/etc/php-fpm.d/www.conf.bak # 做备份
    sed -i "s#listen = /data/data/com.termux/files/usr/var/run/php-fpm.sock#listen = 0.0.0.0:9000#g" $PREFIX/etc/php-fpm.d/www.conf

    # 修改nginx配置文件
    cp $PREFIX/etc/nginx/nginx.conf $PREFIX/etc/nginx/nginx.conf.bak # 做备份
    cat > $PREFIX/etc/nginx/nginx.conf <<'EOF'
worker_processes  1;
events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       8080;
        server_name  localhost;
        location / {
            root   /data/data/com.termux/files/usr/share/nginx/html;
            index  index.html index.htm index.php;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /data/data/com.termux/files/usr/share/nginx/html;
        }

        location ~ \.php$ {
            root           html;
            # fastcgi_pass   127.0.0.1:9000;
            fastcgi_pass   0.0.0.0:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  /data/data/com.termux/files/usr/share/nginx/html$fastcgi_script_name;
            include        fastcgi_params;
        }
    }
}
EOF

    # 测试 PHP 解析
    nginx -s reload # 重启nginx
    echo "<?php phpinfo();?>" > $PREFIX/share/nginx/html/info.php  # 创建测试文件
    curl -I 127.0.0.1:8080/info.php  # 能看到X-Powered-By响应头显示php的版本则说明服务已运行

    # 安装 MariaDB (MySQL)
    # 当 MariaDB Server 的前身 MySQL 于 2009 年被 Oracle 收购时，MySQL 创始人 Michael “Monty” Widenius 出于对 Oracle 管理权的担忧而 fork 了该项目，并将新项目命名为 MariaDB。 MySQL 以他的第一个女儿 My 命名，而 MariaDB 则以他的第二个女儿 Maria 命名。
    pkg install -y mariadb
    mariadb --version  # 或 mysql --version
    mkdir -p $HOME/log; nohup mysqld > $HOME/log/mariadb.log 2>&1 &  # 将mysql守护进程挂到后台运行
    # ps aux | grep -v grep | grep "mysqld" | awk '{print $2}' | xargs kill -9 # 终止mysqld进程

    # 克隆 DVWA 仓库并进行配置
    pkg install git
    git clone -c http.proxy="127.0.0.1:10808" https://github.com/digininja/DVWA.git $PREFIX/share/nginx/html/dvwa # http代理需要自行研究，如果不使用代理也能克隆的话可以去掉代理
    cp $PREFIX/share/nginx/html/dvwa/config/config.inc.php.dist $PREFIX/share/nginx/html/dvwa/config/config.inc.php
    cp $PREFIX/share/nginx/html/dvwa/config/config.inc.php $PREFIX/share/nginx/html/dvwa/config/config.inc.php.bak
    cat > $PREFIX/share/nginx/html/dvwa/config/config.inc.php <<'EOF'
<?php

# If you are having problems connecting to the MySQL database and all of the variables below are correct
# try changing the 'db_server' variable from localhost to 127.0.0.1. Fixes a problem due to sockets.
#   Thanks to @digininja for the fix.

# Database management system to use
$DBMS = getenv('DBMS') ?: 'MySQL';
#$DBMS = 'PGSQL'; // Currently disabled

# Database variables
#   WARNING: The database specified under db_database WILL BE ENTIRELY DELETED during setup.
#   Please use a database dedicated to DVWA.
#
# If you are using MariaDB then you cannot use root, you must use create a dedicated DVWA user.
#   See README.md for more information on this.
$_DVWA = array();
# $_DVWA[ 'db_server' ]   = getenv('DB_SERVER') ?: '127.0.0.1';
$_DVWA[ 'db_server' ]   = getenv('DB_SERVER') ?: '0.0.0.0';
$_DVWA[ 'db_database' ] = getenv('DB_DATABASE') ?: 'dvwa';
# $_DVWA[ 'db_user' ]     = getenv('DB_USER') ?: 'dvwa';
# $_DVWA[ 'db_password' ] = getenv('DB_PASSWORD') ?: 'p@ssw0rd';
$_DVWA[ 'db_user' ]     = 'root';
$_DVWA[ 'db_password' ] = '';
$_DVWA[ 'db_port']      = getenv('DB_PORT') ?: '3306';

# ReCAPTCHA settings
#   Used for the 'Insecure CAPTCHA' module
#   You'll need to generate your own keys at: https://www.google.com/recaptcha/admin
$_DVWA[ 'recaptcha_public_key' ]  = getenv('RECAPTCHA_PUBLIC_KEY') ?: '';
$_DVWA[ 'recaptcha_private_key' ] = getenv('RECAPTCHA_PRIVATE_KEY') ?: '';

# Default security level
#   Default value for the security level with each session.
#   The default is 'impossible'. You may wish to set this to either 'low', 'medium', 'high' or impossible'.
$_DVWA[ 'default_security_level' ] = getenv('DEFAULT_SECURITY_LEVEL') ?: 'impossible';

# Default locale
#   Default locale for the help page shown with each session.
#   The default is 'en'. You may wish to set this to either 'en' or 'zh'.
$_DVWA[ 'default_locale' ] = getenv('DEFAULT_LOCALE') ?: 'en';

# Disable authentication
#   Some tools don't like working with authentication and passing cookies around
#   so this setting lets you turn off authentication.
$_DVWA[ 'disable_authentication' ] = getenv('DISABLE_AUTHENTICATION') ?: false;

define ('MYSQL', 'mysql');
define ('SQLITE', 'sqlite');

# SQLi DB Backend
#   Use this to switch the backend database used in the SQLi and Blind SQLi labs.
#   This does not affect the backend for any other services, just these two labs.
#   If you do not understand what this means, do not change it.
$_DVWA['SQLI_DB'] = getenv('SQLI_DB') ?: MYSQL;
#$_DVWA['SQLI_DB'] = SQLITE;
#$_DVWA['SQLITE_DB'] = 'sqli.db';

?>
EOF
    # 完成配置后手机浏览器访问 http://127.0.0.1:8080/dvwa/setup.php 即可看到 DVWA 的设置页面，点击底部的 Create/Reset Database 即可配置好数据库并进入 DVWA 的登录界面，输入 m 默认用户名 admin 和密码 password 即可登录到 DVWA
    # 默认情况下 php 的 allow_url_include 函数是禁用的，这会影响到 DVWA 文件包含漏洞实验的正常进行，因此需要启用此函数：
    # ~ $ php --ini
    # Configuration File (php.ini) Path: "/data/data/com.termux/files/usr/etc/php"
    # Loaded Configuration File:         (none)
    # Scan for additional .ini files in: "/data/data/com.termux/files/usr/etc/php/conf.d"
    # Additional .ini files parsed:      (none)
    # 发现 php.ini 的文件应该存放在 /data/data/com.termux/files/usr/etc/php 或 /data/data/com.termux/files/usr/etc/php/conf.d目录下，但是 PHP 没有找到配置文件，所以需要我们手动在这个目录下新建 php.ini 配置文件:
    # echo "allow_url_include = On" >> $PREFIX/lib/php.ini
    mkdir -p $PREFIX/etc/php/conf.d/; echo 'allow_url_include = On' > $PREFIX/etc/php/conf.d/custom.ini # 创建配置文件
    # mkdir -p $PREFIX/etc/php/conf.d/; echo 'allow_url_include = Off' > $PREFIX/etc/php/conf.d/custom.ini # 创建配置文件
    # 修改完成之后需要重启 php-fpm：
    ps aux | grep -v grep | grep "php-fpm" | awk '{print $2}' | xargs kill -9 # 终止php-fpm进程
    php-fpm  # 再次启动php-fpm
    
    # 克隆 sqli 仓库并进行配置
    # 由于原版的 sqli-labs 的上一次更新提交已是 2014 年，其内置的 mysql_connect () 函数已被 php7 + 版本删除，这导致了 sqli-labs 连接不上数据库，推荐的解决方法是直接使用 Sqli_Edited_Version 这个修改了连接函数为受支持函数的复刻版：
    git clone -c http.proxy="127.0.0.1:10808" https://github.com/Rinkish/Sqli_Edited_Version.git $PREFIX/share/nginx/html/sqli
    cp -r $PREFIX/share/nginx/html/sqli $PREFIX/share/nginx/html/sqli_bak
    mv $PREFIX/share/nginx/html/sqli/sqlilabs/ $PREFIX/share/nginx/html/sqli/sqli && mv $PREFIX/share/nginx/html/sqli/sqli/* $PREFIX/share/nginx/html/sqli
    # 执行以下命令修改配置文件：
    # sed -i "/^\$host = 'localhost';/c#\$host = 'localhost';\n\$host = '127.0.0.1';" $PREFIX/share/nginx/html/sqli/sql-connections/db-creds.inc
    sed -i "/^\$host = 'localhost';/c#\$host = 'localhost';\n\$host = '0.0.0.0';" $PREFIX/share/nginx/html/sqli/sql-connections/db-creds.inc
    # 此时再用手机浏览器访问 http://127.0.0.1:8080/sqli/sql-connections/setup-db.php 即可自动创建好 sqli-labs 的数据库：http://127.0.0.1:8080/sqli/sql-connections/setup-db.php
    ;;
  uninstall)
    echo "开始卸载 DVWA 环境..."
    
    # 1. 停止所有相关服务
    echo "停止相关服务..."
    # 停止 sshd
    pkill -f sshd 2>/dev/null || true
    
    # 停止 nginx
    nginx -s stop 2>/dev/null || pkill -f nginx 2>/dev/null || true
    
    # 停止 php-fpm
    pkill -f php-fpm 2>/dev/null || true
    
    # 停止 mysqld
    pkill -f mysqld 2>/dev/null || true
    
    # 2. 从 .bashrc 中移除自启动配置
    echo "移除自启动配置..."
    if grep -q "^# Termux services auto-start" "$HOME/.bashrc" 2>/dev/null; then
      # 删除整个配置块（从标记行开始到下一个空行）
      sed -i '/^# Termux services auto-start/,/^$/d' "$HOME/.bashrc"
    fi
    
    # 3. 恢复原始配置文件
    echo "恢复原始配置文件..."
    
    # 恢复 php-fpm 配置
    if [ -f "$PREFIX/etc/php-fpm.d/www.conf.bak" ]; then
      cp "$PREFIX/etc/php-fpm.d/www.conf.bak" "$PREFIX/etc/php-fpm.d/www.conf"
      echo "已恢复 php-fpm 配置文件"
    fi
    
    # 恢复 nginx 配置
    if [ -f "$PREFIX/etc/nginx/nginx.conf.bak" ]; then
      cp "$PREFIX/etc/nginx/nginx.conf.bak" "$PREFIX/etc/nginx/nginx.conf"
      echo "已恢复 nginx 配置文件"
    fi
    
    # 删除自定义 php 配置
    if [ -f "$PREFIX/etc/php/conf.d/custom.ini" ]; then
      rm "$PREFIX/etc/php/conf.d/custom.ini"
      echo "已删除自定义 PHP 配置"
    fi
    
    # 4. 清理安装的文件
    echo "清理安装的文件..."
    
    # 删除 DVWA
    if [ -d "$PREFIX/share/nginx/html/dvwa" ]; then
      rm -rf "$PREFIX/share/nginx/html/dvwa"
      echo "已删除 DVWA"
    fi
    
    # 删除 sqli-labs
    if [ -d "$PREFIX/share/nginx/html/sqli" ]; then
      rm -rf "$PREFIX/share/nginx/html/sqli"
      echo "已删除 SQLI-Labs"
    fi
    
    if [ -d "$PREFIX/share/nginx/html/sqli_bak" ]; then
      rm -rf "$PREFIX/share/nginx/html/sqli_bak"
      echo "已删除 SQLI-Labs 备份"
    fi
    
    # 删除测试文件
    if [ -f "$PREFIX/share/nginx/html/info.php" ]; then
      rm "$PREFIX/share/nginx/html/info.php"
      echo "已删除 PHP 测试文件"
    fi
    
    # 5. 卸载安装的软件包（可选，谨慎使用）
    read -p "是否要卸载相关软件包？(y/N): " confirm
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
      echo "卸载软件包..."
      pkg remove openssh nginx php-fpm mariadb git -y
      echo "软件包已卸载"
    else
      echo "跳过软件包卸载"
    fi
    
    # 6. 清理日志文件
    echo "清理日志文件..."
    if [ -d "$HOME/log" ]; then
      rm -f "$HOME/log/nginx.log" 2>/dev/null || true
      rm -f "$HOME/log/mariadb.log" 2>/dev/null || true
      rm -f "$HOME/log/php-fpm.log" 2>/dev/null || true
      echo "已清理日志文件"
    fi
    
    # 7. 清理备份文件
    echo "清理备份文件..."
    rm -f "$HOME/.bashrc_bak" 2>/dev/null || true
    rm -f "$PREFIX/etc/php-fpm.d/www.conf.bak" 2>/dev/null || true
    rm -f "$PREFIX/etc/nginx/nginx.conf.bak" 2>/dev/null || true
    
    # 8. 删除 DVWA 配置文件备份
    if [ -f "$PREFIX/share/nginx/html/dvwa/config/config.inc.php.bak" ]; then
      rm -f "$PREFIX/share/nginx/html/dvwa/config/config.inc.php.bak" 2>/dev/null || true
    fi
    
    echo "=========================================="
    echo "卸载完成！"
    echo "已移除："
    echo "1. 所有相关服务（sshd、nginx、php-fpm、mysqld）"
    echo "2. .bashrc 中的自启动配置"
    echo "3. DVWA 和 SQLI-Labs 应用文件"
    echo "4. 所有修改的配置文件（已恢复原始备份）"
    echo "5. 所有创建的备份文件"
    echo "=========================================="
    
    # 重新加载 bashrc
    source "$HOME/.bashrc" 2>/dev/null || true
    ;;
  auto-start)
    # 服务自启
    cp $HOME/.bashrc $HOME/.bashrc_bak
    mkdir -p $HOME/log

    # 检查是否已存在配置，避免重复添加
    if ! grep -q "^# Termux services auto-start" "$HOME/.bashrc" 2>/dev/null; then
      cat >> $HOME/.bashrc <<'EOF'
# Termux services auto-start (managed by script)
sshd
nohup nginx > $HOME/log/nginx.log 2>&1 &
nohup mysqld > $HOME/log/mariadb.log 2>&1 &
nohup php-fpm > $HOME/log/php-fpm.log 2>&1 &
EOF
    else
      # 如果已存在但被注释，则取消注释（包括注释后的空格）
      sed -i '/^# sshd/s/^# //' $HOME/.bashrc
      sed -i '/^# nohup nginx > \$HOME\/log\/nginx\.log 2>&1 &/s/^# //' $HOME/.bashrc
      sed -i '/^# nohup mysqld > \$HOME\/log\/mariadb\.log 2>&1 &/s/^# //' $HOME/.bashrc
      sed -i '/^# nohup php-fpm > \$HOME\/log\/php-fpm\.log 2>&1 &/s/^# //' $HOME/.bashrc
    fi
    source $HOME/.bashrc
    ;;

  no-auto-start)
    # 注释掉相关服务启动命令，注释符后加空格
    sed -i '/^sshd/s/^/# /' $HOME/.bashrc
    sed -i '/^nohup nginx > \$HOME\/log\/nginx\.log 2>&1 &$/s/^/# /' $HOME/.bashrc
    sed -i '/^nohup mysqld > \$HOME\/log\/mariadb\.log 2>&1 &$/s/^/# /' $HOME/.bashrc
    sed -i '/^nohup php-fpm > \$HOME\/log\/php-fpm\.log 2>&1 &$/s/^/# /' $HOME/.bashrc
    source $HOME/.bashrc
    ;;
  info)
    echo "访问链接1：http://127.0.0.1:8080/info.php"
    echo "访问链接2：http://127.0.0.1:8080/dvwa/setup.php"
    echo "访问链接3：http://127.0.0.1:8080/sqli/sql-connections/setup-db.php"
    echo "完成配置后手机浏览器访问 http://127.0.0.1:8080/dvwa/setup.php 即可看到 DVWA 的设置页面，点击底部的 Create/Reset Database 即可配置好数据库并进入 DVWA 的登录界面，输入 m 默认用户名 admin 和密码 password 即可登录到 DVWA"
    ;;
  start)
    # 批量运行
    nohup nginx > $HOME/log/nginx.log 2>&1 &
    nohup mysqld > $HOME/log/mariadb.log 2>&1 &
    nohup php-fpm > $HOME/log/php-fpm.log 2>&1 &
    ;;
  stop)
    ps aux | grep -v grep | grep -E "(nginx|mysqld|php-fpm)" | awk '{print $2}' | xargs kill -9 # 批量终止指定进程
    ;;
  *)
    echo "Usage:"
    echo "$0 start|stop"
    ;;
esac

