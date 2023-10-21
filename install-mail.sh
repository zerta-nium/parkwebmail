#!/usr/bin/env bash

read -p "Mailadmin Pass: " mailadmin_pass
read -p "Mailserver Pass: " mailserver_pass
read -p "Domain Name: " domain

# Hostname
hostnamectl set-hostname $domain
hostname -f

# Install Packages
apt update
apt upgrade
sudo add-apt-repository ppa:ondrej/nginx
sudo add-apt-repository ppa:ondrej/php
sudo apt install nginx php8.2-fpm php8.2-common php8.2-mysql php8.2-xml php8.2-xmlrpc php8.2-curl php8.2-gd php8.2-imagick php8.2-cli php8.2-dev php8.2-imap php8.2-mbstring php8.2-opcache php8.2-redis php8.2-soap php8.2-zip php8.2-cli -y
sudo apt install mariadb-server postfix postfix-mysql dovecot-core dovecot-mysql dovecot-imapd dovecot-lmtpd dovecot-sieve dovecot-managesieved rspamd fail2ban redis certbot -y
sudo apt install opendkim opendkim-tools postfix-policyd-spf-python postfix-pcre

## Postfix Admin
wget -O postfixadmin.tgz https://github.com/postfixadmin/postfixadmin/archive/postfixadmin-3.3.11.tar.gz
tar xvf postfixadmin.tgz 
rm -f postfixadmin.tgz
mv postfixadmin-postfixadmin-3.3.11 /var/www/html/postfixadmin
mkdir /var/www/html/postfixadmin/templates_c
chown www-data: /var/www/html/postfixadmin/templates_c
chown -R www-data: /var/www/html/postfixadmin/

#SSL
sudo certbot certonly --webroot -d $domain --email hadrien@zertanium.com -w /var/www/_letsencrypt -n --agree-tos --force-renewal

# Backup original files
mkdir ~/mailbackup
sudo cp /etc/dovecot ~/mailbackup/dovecot
sudo cp /etc/postfix ~/mailbackup/postfix
sudo cp /etc/nginx ~/mailbackup/nginx

# Move new files
find "~/parkwebmail/dovecot" -type f -exec mv {} "/etc/dovecot" \;
find "~/parkwebmail/postfix" -type f -exec mv {} "/etc/postfix" \;
find "~/parkwebmail/nginx" -type f -exec mv {} "/etc/nginx" \;
sudo mv ~/parkwebmail/quota-warning.sh /usr/local/bin/quota-warning.sh
sudo mv ~/parkwebmail/postfixadmin /var/www/html/postfixadmin/config.inc.php


# MariaDB
sudo mysql_secure_installation
sudo mysql <<EOF
CREATE DATABASE IF NOT EXISTS postfixadmin;
GRANT ALL ON postfixadmin.* TO 'mailadmin'@'localhost' IDENTIFIED BY '$mailadmin_pass';
GRANT ALL ON postfixadmin.* TO 'mailserver'@'127.0.0.1' IDENTIFIED BY '$mailserver_pass';
FLUSH PRIVILEGES;
EOF

#Changes in file
sed -i "s/maildomain/$domain/g" /etc/dovecot/conf.d/10-ssl.conf
sed -i "s/maildomain/$domain/g" /etc/postfix/main.cf
sed -i "s/changeme/$mailserver_pass/g" /etc/dovecot/dovecot-sql.conf.ext
sed -i "s/changeme/$mailserver_pass/g" /etc/postfix/sql/mysql_virtual_alias_domain_catchall_maps.cf
sed -i "s/changeme/$mailserver_pass/g" /etc/postfix/sql/mysql_virtual_alias_domain_mailbox_maps.cf
sed -i "s/changeme/$mailserver_pass/g" /etc/postfix/sql/mysql_virtual_alias_domain_maps.cf
sed -i "s/changeme/$mailserver_pass/g" /etc/postfix/sql/mysql_virtual_alias_maps.cf
sed -i "s/changeme/$mailserver_pass/g" /etc/postfix/sql/mysql_virtual_domains_maps.cf
sed -i "s/changeme/$mailserver_pass/g" /etc/postfix/sqlmysql_virtual_mailbox_maps.cf
sed -i "s/changememail/$mailadmin_pass/g" /etc/postfix/sqlmysql_virtual_mailbox_maps.cf
sed -i "s/changeme/$domain/g" /etc/nginx/sites-available/postfixadmin.conf

## Postfix
chmod 0640 /etc/postfix/sql/*
chgrp postfix /etc/postfix/sql/mysql-*.cf
chmod u=rw,g=r,o= /etc/postfix/sql/mysql-*.cf

## DOVECOT
groupadd -g 5000 vmail
useradd -g vmail -u 5000 vmail -d /var/vmail -m
chown -R vmail:vmail /var/vmail
chown root:root /etc/dovecot/dovecot-sql.conf.ext
chmod go= /etc/dovecot/dovecot-sql.conf.ext
chmod +x /usr/local/bin/quota-warning.sh
sudo gpasswd -a www-data dovecot
sudo setfacl -R -m u:www-data:rwx /var/run/dovecot/stats-reader /var/run/dovecot/stats-writer

## End of script
echo "The mail server is installed."
echo "------------------------------------------------"
echo "Mailadmin Pass: $mailadmin_pass"
echo "Mailserver Pass: $mailserver_pass"
echo "Domain Name:  $domain"
echo "------------------------------------------------"

cat << EOF >> ~/mailbackup/mail.txt
------------------------------------------------
Mailadmin Pass: $(mailadmin_pass)
Mailserver Pass: $(mailserver_pass)
Domain Name:  $(domain)
------------------------------------------------
EOF