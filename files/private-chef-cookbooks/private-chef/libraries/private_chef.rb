#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
#
# All Rights Reserved
#

require 'mixlib/config'
require 'chef/mash'
require 'chef/json_compat'
require 'chef/mixin/deep_merge'
require 'securerandom'

module PrivateChef
  extend(Mixlib::Config)

  # options are 'standalone', 'manual', 'ha', and 'tier'
  topology "standalone"

  couchdb Mash.new
  rabbitmq Mash.new
  opscode_solr Mash.new
  opscode_expander Mash.new
  opscode_chef Mash.new
  opscode_erchef Mash.new
  opscode_webui Mash.new
  lb Mash.new
  mysql Mash.new
  postgresql Mash.new
  redis Mash.new
  opscode_authz Mash.new
  opscode_certificate Mash.new
  opscode_org_creator Mash.new
  opscode_account Mash.new
  bootstrap Mash.new
  drbd Mash.new
  keepalived Mash.new
  nagios Mash.new
  nrpe Mash.new
  nginx Mash.new

  servers Mash.new
  backend_vips Mash.new
  api_fqdn nil 
  node nil

  notification_email nil
  database_type nil


  class << self

    def server(name=nil, opts={})
      if name
        PrivateChef["servers"] ||= Mash.new
        PrivateChef["servers"][name] = Mash.new(opts)
      end
      PrivateChef["servers"]
    end

    def servers
      PrivateChef["servers"]
    end

    def backend_vip(name=nil, opts={})
      if name
        PrivateChef['backend_vips'] ||= Mash.new
        PrivateChef['backend_vips']["fqdn"] = name
        opts.each do |k,v|
          PrivateChef['backend_vips'][k] = v
        end
      end
      PrivateChef['backend_vips']
    end

    def generate_secrets
      existing_secrets ||= Hash.new
      if File.exists?("/etc/opscode/private-chef-secrets.json")
        existing_secrets = Chef::JSONCompat.from_json(File.read("/etc/opscode/private-chef-secrets.json"))
      end
      existing_secrets.each do |k, v|
        v.each do |pk, p|
          PrivateChef[k][pk] = p
        end
      end

      PrivateChef['rabbitmq']['password'] ||= SecureRandom.hex(50)
      PrivateChef['rabbitmq']['jobs_password'] ||= SecureRandom.hex(50)
      PrivateChef['opscode_webui']['cookie_secret'] ||= SecureRandom.hex(50)
      PrivateChef['mysql']['sql_password'] ||= SecureRandom.hex(50)
      PrivateChef['postgresql']['sql_password'] ||= SecureRandom.hex(50)
      PrivateChef['postgresql']['sql_ro_password'] ||= SecureRandom.hex(50)
      PrivateChef['opscode_account']['session_secret_key'] ||= SecureRandom.hex(50)
      PrivateChef['nagios']['admin_password'] ||= SecureRandom.hex(50)
      PrivateChef['drbd']['shared_secret'] ||= SecureRandom.hex(30)
      PrivateChef['keepalived']['vrrp_instance_password'] ||= SecureRandom.hex(50)
      PrivateChef['opscode_authz']['superuser_id'] ||= SecureRandom.hex(32)

      if File.directory?("/etc/opscode")
        File.open("/etc/opscode/private-chef-secrets.json", "w") do |f|
          f.puts(
            Chef::JSONCompat.to_json_pretty({
              'rabbitmq' => { 
                'password' => PrivateChef['rabbitmq']['password'],
                'jobs_password' => PrivateChef['rabbitmq']['jobs_password'],
              },
              'opscode_webui' => {
                'cookie_secret' => PrivateChef['opscode_webui']['cookie_secret'],
              },
              'mysql' => {
                'sql_password' => PrivateChef['mysql']['sql_password'],
              },
              'postgresql' => {
                'sql_password' => PrivateChef['postgresql']['sql_password'],
                'sql_ro_password' => PrivateChef['postgresql']['sql_ro_password']
              },
              'opscode_account' => {
                'session_secret_key' => PrivateChef['opscode_account']['session_secret_key']
              },
              'nagios' => {
                'admin_password' => PrivateChef['nagios']['admin_password']
              },
              'drbd' => {
                'shared_secret' => PrivateChef['drbd']['shared_secret']
              },
              'keepalived' => {
                'vrrp_instance_password' => PrivateChef['keepalived']['vrrp_instance_password']
              },
              'opscode_authz' => {
                'superuser_id' => PrivateChef['opscode_authz']['superuser_id']
              }
            })
          )
          system("chmod 0600 /etc/opscode/private-chef-secrets.json")
        end
      end
    end

    def generate_hash
      results = { "private_chef" => {} } 
      [
        "couchdb",
        "rabbitmq",
        "opscode_solr",
        "opscode_expander",
        "opscode_chef",
        "opscode_erchef",
        "opscode_webui",
        "lb",
        "mysql",
        "postgresql",
        "redis",
        "opscode_authz",
        "opscode_certificate",
        "opscode_org_creator",
        "opscode_account",
        "bootstrap",
        "drbd",
        "keepalived",
        "nagios",
        "nrpe",
        "notification_email",
        "database_type",
        "nginx"
      ].each do |key|
        rkey = key.gsub('_', '-')
        results['private_chef'][rkey] = PrivateChef[key]
      end

      results
    end

    def gen_api_fqdn
      PrivateChef["lb"]["api_fqdn"] ||= PrivateChef['api_fqdn']
      PrivateChef["lb"]["web_ui_fqdn"] ||= PrivateChef['api_fqdn']
      PrivateChef["nginx"]["server_name"] ||= PrivateChef['api_fqdn'] 
      PrivateChef["nginx"]["url"] ||= "https://#{PrivateChef['api_fqdn']}"
    end

    def gen_nrpe_allowed_hosts
      nrpe_allowed_hosts = [ "127.0.0.1" ]
      if PrivateChef['backend_vips']['ipaddress']
        nrpe_allowed_hosts << PrivateChef['backend_vips']['ipaddress'] 
      end
      PrivateChef['servers'].each do |k,v|
        if v["role"] == "backend" 
          nrpe_allowed_hosts << v["ipaddress"]
        end
      end
      PrivateChef["nrpe"]["allowed_hosts"] ||= nrpe_allowed_hosts 
    end

    def gen_drbd
      PrivateChef['opscode_chef']['sandbox_path'] ||= "/var/opt/opscode/drbd/data/opscode-chef/sandbox"
      PrivateChef['opscode_chef']['checksum_path'] ||= "/var/opt/opscode/drbd/data/opscode-chef/checksum"
      PrivateChef["couchdb"]["data_dir"] ||= "/var/opt/opscode/drbd/data/couchdb" 
      PrivateChef["rabbitmq"]["data_dir"] ||= "/var/opt/opscode/drbd/data/rabbitmq" 
      PrivateChef["opscode_solr"]["data_dir"] ||= "/var/opt/opscode/drbd/data/opscode-solr" 
      PrivateChef["postgresql"]["data_dir"] ||= "/var/opt/opscode/drbd/data/postgresql" 
      PrivateChef["drbd"]["enable"] ||= true
      drbd_role = "primary"
      PrivateChef['servers'].each do |k, v|
        next unless v['role'] == "backend"
        PrivateChef["drbd"][drbd_role] ||= {
          "fqdn" => k,
          "ip" => v['cluster_ipaddress'] || v["ipaddress"]
        }
        drbd_role = "secondary"
      end
    end

    def gen_keepalived(node_name)
      PrivateChef['servers'].each do |k, v|
        next unless v['role'] == "backend"
        next if k == node_name
        PrivateChef['servers'][node_name]['peer_ipaddress'] = v['cluster_ipaddress'] || v['ipaddress']
      end
      PrivateChef["keepalived"]["enable"] ||= true
      PrivateChef["keepalived"]["vrrp_instance_interface"] = backend_vip["heartbeat_device"] 
      PrivateChef["keepalived"]["vrrp_instance_ipaddress"] = backend_vip["ipaddress"] 
      PrivateChef["keepalived"]["vrrp_instance_ipaddress_dev"] = backend_vip["device"] 
      PrivateChef["keepalived"]["vrrp_instance_vrrp_unicast_bind"] = 
        PrivateChef['servers'][node_name]['cluster_ipaddress'] || PrivateChef['servers'][node_name]['ipaddress']
      PrivateChef["keepalived"]["vrrp_instance_vrrp_unicast_peer"] = PrivateChef['servers'][node_name]['peer_ipaddress']
      PrivateChef["keepalived"]["vrrp_instance_ipaddress_dev"] = backend_vip["device"] 
      PrivateChef["couchdb"]["ha"] ||= true
      PrivateChef["rabbitmq"]["ha"] ||= true
      PrivateChef["opscode_solr"]["ha"] ||= true
      PrivateChef["opscode_expander"]["ha"] ||= true
      PrivateChef["opscode_chef"]["ha"] ||= true
      PrivateChef["opscode_erchef"]["ha"] ||= true
      PrivateChef["opscode_webui"]["ha"] ||= true
      PrivateChef["lb"]["ha"] ||= true
      PrivateChef["postgresql"]["ha"] ||= true
      PrivateChef["redis"]["ha"] ||= true
      PrivateChef["opscode_authz"]["ha"] ||= true
      PrivateChef["opscode_certificate"]["ha"] ||= true
      PrivateChef["opscode_org_creator"]["ha"] ||= true
      PrivateChef["opscode_account"]["ha"] ||= true
      PrivateChef["nginx"]["ha"] ||= true
      PrivateChef["nagios"]["ha"] ||= true
    end

    def gen_backend(bootstrap=false)
      PrivateChef["couchdb"]["bind_address"] ||= "0.0.0.0" 
      PrivateChef["rabbitmq"]["node_ip_address"] ||= "0.0.0.0" 
      PrivateChef["opscode_solr"]["ip_address"] ||= "0.0.0.0"
      PrivateChef["opscode_chef"]["worker_processes"] ||= 6 
      PrivateChef["opscode_webui"]["worker_processes"] ||= 2 
      PrivateChef["postgresql"]["listen_address"] ||= "0.0.0.0" 
      PrivateChef["postgresql"]["md5_auth_cidr_addresses"] ||= ["0.0.0.0/0", "::0/0"] 

      PrivateChef["redis"]["bind"] ||= "0.0.0.0" 
      PrivateChef["opscode_account"]["worker_processes"] ||= 4 
      if bootstrap 
        PrivateChef["bootstrap"]["enable"] = true 
      else
        PrivateChef["bootstrap"]["enable"] = false 
      end
    end

    def gen_frontend
      PrivateChef["couchdb"]["enable"] ||= false
      PrivateChef["couchdb"]["vip"] ||= PrivateChef["backend_vips"]["ipaddress"]
      PrivateChef["rabbitmq"]["enable"] ||= false
      PrivateChef["rabbitmq"]["vip"] ||= PrivateChef["backend_vips"]["ipaddress"]
      PrivateChef["opscode_solr"]["enable"] ||= false
      PrivateChef["opscode_solr"]["vip"] ||= PrivateChef["backend_vips"]["ipaddress"]
      PrivateChef["opscode_expander"]["enable"] ||= false
      PrivateChef["opscode_org_creator"]["enable"] ||= false
      PrivateChef["postgresql"]["enable"] ||= false
      PrivateChef["postgresql"]["vip"] ||= PrivateChef["backend_vips"]["ipaddress"]
      PrivateChef["redis"]["enable"] ||= false
      PrivateChef["redis"]["vip"] ||= PrivateChef["backend_vips"]["ipaddress"]
      PrivateChef["opscode_chef"]["upload_vip"] ||= PrivateChef['backend_vips']['ipaddress'] 
      PrivateChef["opscode_chef"]["upload_port"] ||= 443
      PrivateChef["opscode_chef"]["upload_proto"] ||= "https"
      PrivateChef["opscode_chef"]["upload_internal_vip"] ||= PrivateChef['backend_vips']['ipaddress'] 
      PrivateChef["opscode_chef"]["upload_internal_port"] ||= 9680
      PrivateChef["lb"]["cache_cookbook_files"] ||= true
      PrivateChef["nagios"]["enable"] ||= false
      PrivateChef["bootstrap"]["enable"] = false 
    end

    def gen_redundant(node_name, ha=false)
      raise "Please add a server section for #{node_name} to /etc/opscode/private-chef.rb!" unless PrivateChef['servers'].has_key?(node_name)
      me = PrivateChef["servers"][node_name]
      case me["role"]
      when "backend"
        gen_backend(me['bootstrap'])
        gen_drbd if ha
        gen_keepalived(node_name) if ha
        gen_api_fqdn
      when "frontend"
        gen_frontend
        gen_api_fqdn
      else
        raise "I dont have a role for you! Use 'backend' or 'frontend'."
      end
    end

    def generate_config(node_name)
      generate_secrets
      gen_nrpe_allowed_hosts

      case PrivateChef['topology']
      when "standalone","manual"
        PrivateChef[:api_fqdn] ||= node_name 
        gen_api_fqdn 
      when "ha","tier"
        if PrivateChef['topology'] == "ha"
          gen_redundant(node_name, true)
        else
          gen_redundant(node_name, false)
        end
      else
        Chef::Log.fatal("I do not understand topology #{PrivateChef.topology} - try standalone, manual, ha or tier.")
        exit 55
      end
      generate_hash
    end
  end
end
