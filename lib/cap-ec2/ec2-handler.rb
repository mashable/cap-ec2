module CapEC2
  class EC2Handler
    include CapEC2::Utils
    
    def initialize(ec2_config = "config/ec2.yml")
      @ec2_config = YAML.load_file ec2_config
      @ec2 = {}
      @ec2_config["regions"].each do |region|
        @ec2[region] = AWS::EC2.new(
        access_key_id: @ec2_config["access_key_id"],
        secret_access_key: @ec2_config["secret_access_key"],
        region: region
      )
      end
    end
    
    def status_table
      CapEC2::StatusTable.new(
        defined_roles.map {|r| get_servers_for_role(r)}.flatten.uniq {|i| i.instance_id},
        @ec2_config
      )
    end
    
    def server_names
      puts defined_roles.map {|r| get_servers_for_role(r)}
                   .flatten
                   .uniq {|i| i.instance_id}
                   .map {|i| i.tags["Name"]}
                   .join("\n")
    end
    
    def instance_ids
      puts defined_roles.map {|r| get_servers_for_role(r)}
                   .flatten
                   .uniq {|i| i.instance_id}
                   .map {|i| i.instance_id}
                   .join("\n")
    end
    
    def defined_roles
      Capistrano::Configuration.env.send(:servers).send(:available_roles)
    end
    
    def stage
      Capistrano::Configuration.env.fetch(:stage).to_s
    end
    
    def application
      Capistrano::Configuration.env.fetch(:application).to_s
    end
    
    def tag(tag_name)
      "tag:#{tag_name}"
    end
    
    def get_servers_for_role(role)
      servers = []
      each_region do |ec2|
        instances = ec2.instances
          .filter(tag(project_tag), application)
          .filter('instance-state-code', '16')
        servers << instances.select do |i| 
          i.tags[roles_tag] =~ /,{0,1}#{role}(,|$)/ && i.tags[stages_tag] =~ /,{0,1}#{stage}(,|$)/
        end
      end
      servers.flatten
    end
    
    def each_region
      @ec2.keys.each do |region|
        yield @ec2[region]
      end
    end
    
  end
end