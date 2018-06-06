require 'net/ssh'

puts "Connection ssh"
puts "Ec2 url:"
hostname = gets.chomp
puts "Username:"
username = gets.chomp
puts "Path to your ssh key:"
fileName = gets.chomp

@installZsh = 'sudo apt-get install zsh'
@installMyZsh = 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"'
@installNodeJS = 'git clone https://github.com/tj/n.git && cd n/bin  && sudo ./n stable'
@installNgnix = 'sudo apt-get install nginx'
@installPm2 = 'sudo npm -g install pm2'

begin
  ssh = Net::SSH.start(hostname, username, :keys => fileName)
  zsh = ssh.exec!(@installZsh)
  myZsh = ssh.exec!(@installMyZsh)
  nodejs = ssh.exec!(@installNodeJS)
  ngnix = ssh.exec!(@installNgnix)
  pm2 = ssh.exec!(@installPm2)
  ssh.close
  puts zsh
  puts myZsh
  puts nodejs
  puts nginx
rescue
  puts "Fail to connect to #{username}/#{hostname}"
  exit
end

puts "installation of basique sowftware done, will you like to clone a project ? [Y/n]"
quest = gets.chomp

puts "server side application 1 client side application 2 ? [1/2]"
server = gets.chomp

if quest != 'n'
  puts "github url: "
  gitUrl = gets.chomp
  puts "Project name:"
  projectName = gets.chomp
  begin
    ssh = Net::SSH.start(hostname, username, :keys => fileName)
    clone = ssh.exec!("git clone #{gitUrl} #{projectName} && cd #{projectName}")
    yarnInstall = ssh.exec!("yarn")
    if server == '2'
      yarnBuild = ssh.exec!("yarn build")
    end
    if server == '1'
      pm2 = ssh.exec!(`pm2 start yarn -- "start"`)
      pm2Restart = ssh.exec!(`pm2 restart yarn --name "#{projectName}"`)
    end
    ssh.close
    puts clone
    puts yarnInstall
  rescue
    puts "Fail to connect to #{username}/#{hostname}"
    exit
  end
end


puts "Do you need a Ngnix configuration ? [Y/n]"
quest = gets.chomp
puts "server side application 1 client side application 2 ? [1/2]"
server = gets.chomp
puts "dommaine url:"
dommaineUrl = gets.chomp

if quest == '1' || quest == '2'
  if server == '1'
    puts "add your server port:"
    port = gets.chomp
    @nginxConfigFileServer =`user www-data;
    worker_processes auto;
    pid /run/nginx.pid;

    events {
      worker_connections 768;
      # multi_accept on;
    }

    http {
      ##
      # Logging Settings
      ##
      access_log /var/log/nginx/access.log;
      error_log /var/log/nginx/error.log;
      server {
        listen 80;
        server_name #{dommaineUrl};
        location / {
          # Redirect any http requests to https
          return 301 https://$server_name$request_uri;
        }
      }
      server {
        listen 443 ssl;
        server_name #{dommaineUrl};
        add_header Strict-Transport-Security "max-age=31536000; includeSubdomains; preload";
        location / {
          proxy_pass http://127.0.0.1:#{port};
        }

      }
      }`
      begin
        ssh = Net::SSH.start(hostname, username, :keys => fileName)
        nginxConfig = ssh.exec!("sudo rm /etc/nginx/nginx.conf && sudo echo #{nginxConfigFileServer} > /etc/nginx/nginx.conf")
        nginxRestart = ssh.exec!("sudo service nginx restart")
        ssh.close
        puts nginxConfig
        puts nginxRestart
      rescue
        puts "Fail to connect to #{username}/#{hostname}"
        exit
      end
  elsif server == '2'
      puts "Path to index.html:"
      path = gets.chomp
      @nginxConfigFileClient = `
      user www-data;
      worker_processes auto;
      pid /run/nginx.pid;
      events { worker_connections 768; }
      http {
        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;
        server {
          listen 80;
          expires off;
          server_name #{dommaineUrl};
          root #{path};
          index index.html;
          location / {
            return 301 https://$server_name$request_uri;
          }
        }
        server {
          expires off;
          listen 443 ssl;
          server_name #{dommaineUrl};
          add_header Strict-Transport-Security "max-age=31536000; includeSubdomains; preload";
          root #{path};
          index index.html;
          location ~* \.(?:manifest|appcache|html?|xml|json)$ {
            expires off;
          }
          location ~* \.(?:css|js)$ {
            try_files $uri =404;
            expires off;
            access_log off;
            add_header Cache-Control "public";
          }

          location ~ ^.+\..+$ {
            expires off;
            try_files $uri =404;
          }
          location / {
            expires off;
            try_files $uri $uri/ /index.html;
          }
        }
        }`
        begin
          ssh = Net::SSH.start(hostname, username, :keys => fileName)
          nginxConfig = ssh.exec!("sudo rm /etc/nginx/nginx.conf && sudo echo #{nginxConfigFileClient} > /etc/nginx/nginx.conf")
          nginxRestart = ssh.exec!("sudo service nginx restart")
          ssh.close
          puts nginxConfig
          puts nginxRestart
        rescue
          puts "Fail to connect to #{username}/#{hostname}"
          exit
        end
      end
    end


#TODO SSL certificate
