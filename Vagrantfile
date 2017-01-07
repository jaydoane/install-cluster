# -*- mode: ruby -*-
# vi: set ft=ruby :

# compose and provision a cloudant local cluster
# https://github.com/fabriziopandini/vagrant-compose/

PROVISION_DIR = 'provision'

NON_AUTO_UPDATE_VBGUEST_PLATFORMS = ['sles12']

PLATFORMS = {
  'precise' => {
    :box => 'ubuntu/precise64',
    :ip_index => 1},
  'trusty' => {
    :box => 'ubuntu/trusty64',
    :ip_index => 2},
  'el6' => {
    :box => 'centos/6',
    :ip_index => 3},
  'el7' => {
    :box => 'centos/7',
    :ip_index => 4},
  'sles12' => {
    :box => 'elastic/sles-12-x86_64',
    :ip_index => 5}}

# since installer names from IBM download are horribly inconsistent,
# we may have to infer the version from its name
INSTALLER_VERSION_MATCHER = {
  '1.0.0.2' => /CLO_DLL_EDI_1.0/,
  '1.0.0.3' => /1.0.0.3/,
  '1.0.0.5' => /IBM_CLOUDANT_DATA_LAYER_LOCAL_ED/}

LATEST_VERSION = '1.1.0'

def path_to_version(path)
  INSTALLER_VERSION_MATCHER.each do |version, re|
    if path.include? version
      return version
    elsif path =~ re
      return version
    end
  end
  return LATEST_VERSION
end

def db_node_count() (ENV['db_nodes'] || '3').to_i end
def lb_node_count() (ENV['lb_nodes'] || '1').to_i end
def dbx_node_count() (ENV['dbx_nodes'] || '0').to_i end
def user() ENV['USER'] end
def domain() ENV['domain'] || "#{platform}.#{user}" end
def ip_prefix() ENV['ip_prefix'] || '172.31' end
def ip_platform_prefix() "#{ip_prefix}.#{PLATFORMS[platform][:ip_index]}" end
def memory() ENV['memory'] || 1024 end
def cpus() ENV['cpus'] || 1 end
def build() ENV['build'] || 'latest' end
def platform() ENV['platform'] || 'trusty' end
def box() PLATFORMS[platform][:box] end
def reinstall?() ['true', 'yes'].include?(ENV['reinstall']) || false end
def installer() ENV['installer'] || "cloudant-#{build}-#{platform}-x86_64.bin" end
def install_dir() File.join('/root', path_to_version(installer)) end
def version() path_to_version(installer) end
def is_cast_installer() version > '1.0.0.4' end
def is_binary_installer() installer.end_with? 'bin' end

`cd #{PROVISION_DIR}/installers && platform=#{platform} build=#{build} ./sync-installer` if not ENV['installer']
`cd #{PROVISION_DIR}/ssh && ./ensure-keypair.sh`


Vagrant.configure(2) do |config|
  compose_cluster(config)
  config.cluster.debug
  configure_hostmanager(config)
  config.cluster.nodes.each do |composed_node|
    config.vm.define composed_node.boxname do |node|
      configure_vm(node.vm, composed_node)
      provision('uninstall', node, config) if reinstall?
      main = is_cast_installer ? 'main' : 'main-legacy'
      provision(main, node, config)
    end
  end
end

def compose_cluster(config)
  config.vm.synced_folder '.', '/vagrant', type: 'virtualbox'
  config.vbguest.installer = EL7Installer if platform == 'el7'
  config.vbguest.auto_update = false if
    NON_AUTO_UPDATE_VBGUEST_PLATFORMS.include?(platform)
  config.cluster.compose('') do |cluster|
    cluster.box = box
    cluster.domain = domain
    compose_group('db', ['rebal_target'], db_node_count, cluster)
    compose_group('lb', ['rebal_runner'], lb_node_count, cluster)
    compose_group('dbx', ['rebal_target'], dbx_node_count, cluster)
    cluster.ansible_context_vars['db'] = lambda {|context, composed_nodes|
      {'db-nodes' => composed_nodes.map {|n|
         {'fqdn' => n.fqdn,
          'ip' => n.ip}}}}
    cluster.ansible_context_vars['lb'] = lambda {|context, composed_nodes|
      {'lb-nodes' => composed_nodes.map {|n|
         {'fqdn' => n.fqdn,
          'ip' => n.ip}}}}
    cluster.ansible_group_vars['common'] = lambda {|context, composed_nodes| 
      {'platform' => platform,
       'installer' => installer,
       'version' => version,
       'install_dir' => install_dir,
       'is_binary_installer' => is_binary_installer,
       'is_cast_installer' => is_cast_installer,
       'db_nodes' => context['db-nodes'],
       'lb_nodes' => context['lb-nodes'],
       'domain' => cluster.domain}}
    cluster.ansible_host_vars['db'] = lambda { |context, composed_node|
      {'is_first_node' => composed_node.index == 0,
       'is_last_node' => composed_node.index + 1 == db_node_count}} # better way?
    cluster.ansible_playbook_path = File.join(Dir.pwd, PROVISION_DIR)
  end
end

def compose_group(name, ansible_groups, count, cluster)
  cluster.nodes(count, name) do |group|
    group.memory = memory
    group.cpus = cpus
    group.ansible_groups = ['common', name] + ansible_groups
    # reduce number of routes/vboxnets to manually configure
    group.ip = lambda {|group_index, group_name, node_index|
      "#{ip_platform_prefix}.#{group_index + 1}#{node_index + 1}" }
  end
end

def configure_hostmanager(config)
  config.hostmanager.enabled = false
  config.hostmanager.manage_host = true
  config.hostmanager.include_offline = true
end

def configure_vm(vm, composed_node)
  vm.box = composed_node.box
  # NOTE: exit Cisco AnyConnect VPN for private host-only routes
  # see: https://forums.virtualbox.org/viewtopic.php?f=8&t=55066
  vm.network :private_network, ip: composed_node.ip
  vm.hostname = composed_node.fqdn
  vm.provision :hostmanager
  vm.provider :virtualbox do |vb|
    vb.memory = composed_node.memory
    vb.cpus = composed_node.cpus
    # vb.linked_clone = true if Vagrant::VERSION =~ /^1.8/
  end
end

def provision(file_prefix, node, config)
  node.vm.provision :ansible do |a|
    # a.limit = 'all' # enable parallel provisioning
    a.playbook = "#{PROVISION_DIR}/#{file_prefix}.yaml"
    a.groups = config.cluster.ansible_groups
  end
end

# needed to build Virtualbox Guest Additions on centos/7
class EL7Installer < VagrantVbguest::Installers::Linux
  def install(opts=nil, &block)
    ftp_url = 'ftp://fr2.rpmfind.net/linux/centos/7.2.1511/updates/x86_64/Packages'
    el7_kernel_devel_rpm = 'kernel-devel-3.10.0-327.36.3.el7.x86_64.rpm'
    communicate.sudo("curl -O #{ftp_url}/#{el7_kernel_devel_rpm}", opts, &block)
    communicate.sudo('yum -y groupinstall "Development Tools"', opts, &block)
    communicate.sudo("yum -y localinstall #{el7_kernel_devel_rpm}", opts, &block)
    super
  end
end
