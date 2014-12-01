# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "hashicorp/precise64"

  # From https://github.com/geerlingguy/JJG-Ansible-Windows
  require 'rbconfig'
  is_windows = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
  if is_windows
    # Screenshots
    config.vm.synced_folder "#{ENV['HOME']}\\Pictures\\Frontier Developments\\Elite Dangerous", "/images", create: true
    config.vm.synced_folder "#{ENV['HOME']}\\AppData\\Local\\Frontier_Developments\\Products\\FORC-FDEV-D-1002\\Logs", "/logs", create: true
    # Provisioning configuration for shell script.
    config.vm.provision "shell" do |sh|
      sh.path = "provisioning/windows.sh"
      sh.args = "provisioning/playbook.yml provisioning/inventory"
    end
  else
    # Screenshots
    config.vm.synced_folder "images/", "/images", create: true
    # Provisioning configuration for Ansible (for Mac/Linux hosts).
    config.vm.provision "ansible" do |ansible|
      ansible.playbook = "provisioning/playbook.yml"
      ansible.inventory_path = "provisioning/inventory"
      ansible.sudo = true
    end
  end

end
