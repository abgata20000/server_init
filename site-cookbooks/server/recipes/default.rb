# サーバーの設定
template "i18n" do
  owner  "root"
  group  "root"
  mode   "0644"
  path   "/etc/sysconfig/i18n"
  source "i18n.erb"
end

template "network" do
  owner  "root"
  group  "root"
  mode   "0644"
  path   "/etc/sysconfig/network"
  source "network.erb"
end

file "/etc/localtime" do
  action :delete
end

link "/etc/localtime" do
  to "/usr/share/zoneinfo/Asia/Tokyo"
end


service "network" do
  action :restart
end

# ユーザー登録
username = node[:user][:name]

user username do
  password node[:user][:password]
end

group "wheel" do
  action  :modify
  members username
  append  true
end


template "sudoers" do
  owner  "root"
  group  "root"
  path   "/etc/sudoers"
  mode   "0440"
  source "sudoers.erb"
end


directory "/home/#{username}/.ssh" do
  owner  username
  group  username
  mode  "0700"
  action :create
end

cookbook_file "/home/#{username}/.ssh/authorized_keys" do
  owner  username
  group  username
  mode   00600
  source "id_rsa.pub"
end

# add the EPEL repo
yum_repository 'epel' do
  description 'Extra Packages for Enterprise Linux'
  mirrorlist 'http://mirrors.fedoraproject.org/mirrorlist?repo=epel-6&arch=$basearch'
  fastestmirror_enabled true
  gpgkey 'http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6'
  action :create
end

# add the Remi repo
yum_repository 'remi' do
  description 'Les RPM de Remi - Repository'
  baseurl 'http://rpms.famillecollet.com/enterprise/6/remi/x86_64/'
  gpgkey 'http://rpms.famillecollet.com/RPM-GPG-KEY-remi'
  fastestmirror_enabled true
  action :create
end


# yumをアップデート
execute "yum-update" do
  user "root"
  command "yum -y update"
  action :run
end

# yumでインストール
apps = [
  'git',
  'vim-enhanced',
  'openssl',
  'openssl-devel',
  'make',
  'gcc',
  'gcc-c++',
  'httpd',
  'httpd-devel',
  'nginx',
  'mongodb',
  'mongodb-server',
  'ImageMagick',
  'ImageMagick-devel'
]

apps.each do |pkg|
  package pkg do
    action :install
  end
end

# PHP と MySQL の最新版をインストールする
apps = [
  'php',
  'php-devel',
  'php-mysql',
  'php-mbstring',
  'php-gd',
  'php-pear',
  'mysql',
  'mysql-server',
  'mysql-devel'
]

apps.each do |pkg|
  package pkg do
    options "--enablerepo=remi"
    action :install
  end
end


# zsh
package 'zsh' do
  action :install
end

git "/home/#{username}/.zsh.d" do
  repository "https://github.com/abgata20000/zsh.d.git"
  revision   "master"
  user       username
  group      username
  action     :sync
end


bash "setting zsh" do
  user username
  environment "HOME" => "/home/#{username}"
  code <<-EOS
  echo "source ~/.zsh.d/zshrc" > ~/.zshrc
  echo "source ~/.zsh.d/zshenv" > ~/.zshenv
  EOS
end

user username do
  action :modify
  shell '/bin/zsh'
end

bash "setting zsh(root)" do
  user 'root'
  environment "HOME" => "/root"
  code <<-EOS
  echo "source /home/#{username}/.zsh.d/zshrc" > ~/.zshrc
  echo "source /home/#{username}/.zsh.d/zshenv" > ~/.zshenv
  EOS
end

user 'root' do
  action :modify
  shell '/bin/zsh'
end

# iptables
template "iptables" do
  path   "/etc/sysconfig/iptables"
  source "iptables.erb"
end

service "iptables" do
  action [:start, :enable]
end


# sshd
template "sshd_config" do
  owner  "root"
  group  "root"
  mode   "0644"
  path   "/etc/ssh/sshd_config"
  source "sshd_config.erb"
end

service "sshd" do
  action :restart
end


# apache と nginx を共存されるためのモジュールを追加
bash "install apache module" do
  user 'root'
  environment "HOME" => "/root"
  code <<-EOS
  mkdir /root/tmp
  cd /root/tmp
  wget http://www.openinfo.co.uk/apache/extract_forwarded-2.0.2.tar.gz
  tar zxf extract_forwarded-2.0.2.tar.gz
  cd extract_forwarded
  apxs -i -c -a mod_extract_forwarded.c
  EOS
end


# vhostのデフォルトフォルダを作成
directory "/var/www/vhosts/default/public" do
  owner 'nginx'
  group 'nginx'
  recursive true
  mode 0755
  action :create
end

bash "/var/www user group change" do
  user 'root'
  code 'chown nginx:nginx /var/www'
end



# MySQL の設定
template "my.cnf" do
  owner  "root"
  group  "root"
  mode   "0644"
  path   "/etc/my.cnf"
  source "my.cnf.erb"
end

service "mysqld" do
  supports status: true, restart: true, reload: true
  action   [ :enable, :start ]
end

# PHP の設定
template "php.ini" do
  owner  "root"
  group  "root"
  mode   "0644"
  path   "/etc/php.ini"
  source "php.ini.erb"
end

# apacheの設定
template "httpd.conf" do
  owner  "root"
  group  "root"
  mode   "0644"
  path   "/etc/httpd/conf/httpd.conf"
  source "httpd.conf.erb"
end

template "vhosts.conf" do
  owner  "root"
  group  "root"
  mode   "0644"
  path   "/etc/httpd/conf.d/vhosts.conf"
  source "vhosts.conf.erb"
end

service "httpd" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable , :start ]
end

# nginxの設定
%w{avalable enabled}.each do |n|
  directory "/etc/nginx/sites-#{n}" do
    owner 'root'
    group 'root'
    recursive true
    mode 0644
    action :create
    not_if {::File.exists? "/etc/nginx/sites-#{n}"}
  end
end


template "nginx.conf" do
  owner  "root"
  group  "root"
  mode   "0644"
  path   "/etc/nginx/nginx.conf"
  source "nginx.conf.erb"
end

template "default.conf" do
  owner  "root"
  group  "root"
  mode   "0644"
  path   "/etc/nginx/conf.d/default.conf"
  source "default.conf.erb"
end

service "nginx" do
  supports :status => true, :restart => true, :reload => true
  action [:enable , :start]
end

# mongodb の設定
template "mongod.conf" do
  owner  "root"
  group  "root"
  mode   "0644"
  path   "/etc/mongod.conf"
  source "mongod.conf.erb"
end

service "mongod" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable , :start ]
end


# rbenv で Ruby をインストール
user 'ruby' do

end

group "ruby" do
  action  :modify
  members username
  append  true
end

#
bash "install rbenv" do
  user 'root'
  environment "HOME" => "/root"
  code <<-EOS
  cd /usr/local
  git clone git://github.com/sstephenson/rbenv.git rbenv
  mkdir rbenv/shims rbenv/versions rbenv/plugins

  cd rbenv/plugins
  git clone git://github.com/sstephenson/ruby-build.git ruby-build
  cd ruby-build
  ./install.sh

  cd /usr/local

  chgrp -R ruby rbenv
  chmod -R 775 rbenv

  rm -rf /etc/profile.d/rbenv.sh
  echo 'export RBENV_ROOT="/usr/local/rbenv"'     >> /etc/profile.d/rbenv.sh
  echo 'export PATH="/usr/local/rbenv/bin:$PATH"' >> /etc/profile.d/rbenv.sh
  echo 'eval "$(rbenv init -)"'                   >> /etc/profile.d/rbenv.sh

  source /etc/profile.d/rbenv.sh
  EOS
  action :run
end

bash "install ruby" do
  user 'root'
  environment "HOME" => "/root"
  code <<-EOS
  source /etc/profile.d/rbenv.sh
  rbenv install -v #{node['ruby']['version']}

  rbenv global #{node['ruby']['version']}

  rbenv rehash
  EOS
  action :run
  not_if {::File.exists? "/usr/local/rbenv/versions/#{node['ruby']['version']}"}
end

# bundler をインストール
bash "bundler insatll" do
  user 'root'
  environment "HOME" => "/root"
  code <<-EOS
  source /etc/profile.d/rbenv.sh
  gem update
  gem install bundler
  rbenv rehash
  EOS
  action :run
  not_if {::File.exists? "/usr/local/rbenv/shims/bundle"}
end

# nodebrew で node.js をインストール
user 'node' do

end

group "node" do
  action  :modify
  members username
  append  true
end


#
bash "install nodebrew" do
  user 'root'
  environment "HOME" => "/home/node"
  code <<-EOS
  cd /home/node
  wget git.io/nodebrew
  perl nodebrew setup
  rm -rf nodebrew

  rm -rf /etc/profile.d/nodebrew.sh
  echo 'export PATH="/home/node/.nodebrew/current/bin:$PATH"'     >> /etc/profile.d/nodebrew.sh
  source /etc/profile.d/nodebrew.sh
  chown -R node:node /home/node
  chmod -R 775 /home/node
  EOS
  action :run
  not_if {::File.exists? "/home/node/.nodebrew"}
end

bash "install node.js" do
  user 'node'
  environment "HOME" => "/home/node"
  code <<-EOS
  source /etc/profile.d/nodebrew.sh
  nodebrew install-binary #{node['node']['version']}
  nodebrew use #{node['node']['version']}
  EOS
  action :run
  not_if {::File.exists? "/home/node/.nodebrew/node/#{node['node']['version']}"}
end
