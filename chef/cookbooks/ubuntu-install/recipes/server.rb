# Copyright 2011, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package "syslinux"

####
# this recipe prepares the crowbar server to install Ubuntu nodes.
# - create an ubuntu_install DHCP group to be used when nodes are in the "install" state
# - create the relevant enties in /tftp/ubuntu_dvd (kernel config, boot image, seed files etc).  

admin_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
domain_name = node[:dns].nil? ? node[:domain] : (node[:dns][:domain] || node[:domain])
web_port = node[:provisioner][:web_port]
use_local_security = node[:provisioner][:use_local_security]

os_token="#{node[:platform]}-#{node[:platform_version]}"
image="ubuntu_install"
rel_path="#{os_token}/install/#{image}"
install_path = "/tftpboot/#{rel_path}"
pxecfg_path="/tftpboot/discovery/pxelinux.cfg"

append_line="url=http://#{admin_ip}:#{web_port}/#{rel_path}/net_seed debian-installer/locale=en_US.utf8 console-setup/layoutcode=us localechooser/translation/warn-light=true localechooser/translation/warn-severe=true netcfg/dhcp_timeout=120 netcfg/choose_interface=auto netcfg/get_hostname=\"redundant\" initrd=../#{os_token}/install/install/netboot/ubuntu-installer/amd64/initrd.gz ramdisk_size=16384 root=/dev/ram rw quiet --"

if node[:provisioner][:use_serial_console]
  append_line = "console=tty0 console=ttyS1,115200n8 " + append_line
end
if ::File.exists?("/etc/crowbar.install.key")
  append_line = "crowbar.install.key=#{::File.read("/etc/crowbar.install.key").chomp.strip} " + append_line
end

# Make sure the directories need to net_install are there.
directory "#{install_path}"

template "#{pxecfg_path}/#{image}" do
  mode 0644
  owner "root"
  group "root"
  source "default.erb"
  variables(:append_line => "append " + append_line,
            :install_name => image,  
            :kernel => "../#{os_token}/install/install/netboot/ubuntu-installer/amd64/linux")
end

template "#{install_path}/net_seed" do
  mode 0644
  owner "root"
  group "root"
  source "net_seed.erb"
  variables(:install_name => image,  
            :cc_use_local_security => use_local_security,
            :cc_install_web_port => web_port,
            :cc_built_admin_node_ip => admin_ip,
            :install_path => "#{os_token}/install")
end

cookbook_file "#{install_path}/net-post-install.sh" do
  mode 0644
  owner "root"
  group "root"
  source "net-post-install.sh"
end

cookbook_file "#{install_path}/net-pre-install.sh" do
  mode 0644
  owner "root"
  group "root"
  source "net-pre-install.sh"
end

template "#{install_path}/crowbar_join.sh" do
  mode 0644
  owner "root"
  group "root"
  source "crowbar_join.sh.erb"
  variables(:admin_ip => admin_ip)
end

