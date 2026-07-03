Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.hostname = "student-api-prod"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 2048
    vb.cpus = 2
  end

  config.vm.network "forwarded_port", guest: 8080, host: 8080
  config.vm.network "forwarded_port", guest: 5432, host: 5432

  config.vm.synced_folder ".", "/vagrant"

  config.vm.provision "shell", path: "scripts/provision.sh"
  config.vm.provision "shell", inline: "cd /vagrant && docker compose -f docker-compose.vagrant.yml up -d"
end
