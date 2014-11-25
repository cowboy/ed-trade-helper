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
    # Provisioning configuration for shell script.
    config.vm.provision "shell" do |sh|
      sh.path = "provisioning/windows.sh"
      sh.args = "provisioning/playbook.yml"
    end
  else
    # Provisioning configuration for Ansible (for Mac/Linux hosts).
    config.vm.provision "ansible" do |ansible|
      ansible.playbook = "provisioning/playbook.yml"
      ansible.sudo = true
    end
  end

end
