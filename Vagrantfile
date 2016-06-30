# -*- mode: ruby -*-
# vi: set ft=ruby :

# compose and provision a cloudant local cluster
# https://github.com/fabriziopandini/vagrant-compose/

PROVISION_DIR = 'provision'

def db_node_count() (ENV['DB_NODES'] || '3').to_i end
def lb_node_count() (ENV['LB_NODES'] || '1').to_i end
def dbx_node_count() (ENV['DBX_NODES'] || '0').to_i end
def domain() ENV['DOMAIN'] || 'v' end
def ip_prefix() ENV['IP_PREFIX'] || '172.31.0' end
def memory() ENV['MEMORY'] || 1024 end
def vendor() ENV['VENDOR'] || 'ubuntu' end
def platform() ENV['PLATFORM'] || 'trusty' end
def box() "#{vendor}/#{platform}64" end
def reinstall?() ['true', 'yes'].include?(ENV['REINSTALL']) || false end

if ['true', 'yes'].include?(ENV['LATEST'])
  `cd #{PROVISION_DIR}/installers && PLATFORM=#{platform} ./get-latest.sh`
end
`cd #{PROVISION_DIR}/ssh && ./ensure-keypair.sh`


Vagrant.configure(2) do |config|
  compose_cluster(config)
  config.cluster.debug
  configure_hostmanager(config)
  config.cluster.nodes.each do |cnode| # aka "composed_node"
    config.vm.define cnode.boxname do |node|
      configure_vm(node.vm, cnode)
      provision('uninstall', node, config) if reinstall?
      provision('main', node, config)
    end
  end
end

def compose_cluster(config)
  config.cluster.compose('') do |cluster|
    cluster.box = box
    cluster.domain = domain
    compose_group('db', ['rebal_target'], db_node_count, cluster)
    compose_group('lb', ['rebal_runner'], lb_node_count, cluster)
    compose_group('dbx', ['rebal_target'], dbx_node_count, cluster)
    cluster.ansible_context_vars['db'] = lambda {|context, cnodes|
      {'db-nodes' => cnodes.map {|n|
         {'fqdn' => n.fqdn,
          'ip' => n.ip}}}}
    cluster.ansible_group_vars['common'] = lambda {|context, cnodes| 
      {'platform' => platform}}
    cluster.ansible_group_vars['lb'] = lambda {|context, cnodes| 
      {'db_nodes' => context['db-nodes'],
       'domain' => cluster.domain}}
    cluster.ansible_group_vars['db'] = lambda {|context, cnodes| 
      {'db_nodes' => context['db-nodes']}}
    cluster.ansible_host_vars['db'] = lambda { |context, cnode|
      {'is_first_node' => cnode.index == 0,
       'is_last_node' => cnode.index + 1 == db_node_count}} # better way?
    cluster.ansible_playbook_path = File.join(Dir.pwd, PROVISION_DIR)
  end
end

def compose_group(name, ansible_groups, count, cluster)
  cluster.nodes(count, name) do |group|
    group.memory = memory
    group.ansible_groups = ['common', name] + ansible_groups
    # reduce number of routes/vboxnets to manually configure
    group.ip = lambda {|group_index, group_name, node_index|
      "#{ip_prefix}.#{group_index + 1}#{node_index + 1}" }
  end
end

def configure_hostmanager(config)
  config.hostmanager.enabled = false
  config.hostmanager.manage_host = true
  config.hostmanager.include_offline = true
end

def configure_vm(vm, cnode)
  vm.box = cnode.box
  # NOTE: exit Cisco AnyConnect VPN for private host-only routes
  # see: https://forums.virtualbox.org/viewtopic.php?f=8&t=55066
  vm.network :private_network, ip: cnode.ip
  vm.hostname = cnode.fqdn
  vm.provision :hostmanager
  vm.provider :virtualbox do |vb|
    vb.name = cnode.boxname
    vb.memory = cnode.memory
    vb.cpus = cnode.cpus
    vb.linked_clone = true if Vagrant::VERSION =~ /^1.8/
  end
end

def provision(file_prefix, node, config)
  node.vm.provision :ansible do |a|
    # a.limit = 'all' # enable parallel provisioning
    a.playbook = "#{PROVISION_DIR}/#{file_prefix}.yaml"
    a.groups = config.cluster.ansible_groups
  end
end
