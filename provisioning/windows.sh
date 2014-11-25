#!/bin/bash
#
# Based on
# https://github.com/geerlingguy/JJG-Ansible-Windows/blob/master/windows.sh

ANSIBLE_PLAYBOOK="$1"
ANSIBLE_HOSTS="${2:-.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory}"
TEMP_HOSTS="/tmp/ansible_hosts"

if [ ! -f "/vagrant/$ANSIBLE_PLAYBOOK" ]; then
  echo "Cannot find Ansible playbook."
  exit 1
fi

if [ ! -f "/vagrant/$ANSIBLE_HOSTS" ]; then
  echo "Cannot find Ansible hosts."
  exit 2
fi

# Install Ansible and its dependencies if it's not installed already.
if [[ ! "$(type -P ansible)" ]]; then
  echo "Updating APT"
  sudo apt-get -qq update
  echo "Installing python packages"
  sudo apt-get -qq install python-dev python-setuptools
  echo "Installing pip"
  sudo easy_install pip
  echo "Installing ansible"
  sudo pip install ansible
fi

cp /vagrant/${ANSIBLE_HOSTS} ${TEMP_HOSTS} && chmod -x ${TEMP_HOSTS}
echo "Running Ansible provisioner defined in Vagrantfile."
ansible-playbook /vagrant/${ANSIBLE_PLAYBOOK} --inventory-file=${TEMP_HOSTS} --extra-vars "is_windows=true" --connection=local
rm ${TEMP_HOSTS}
