include_recipe "deploy"

node[:deploy].each do |application, deploy|
  deploy = node[:deploy][application]

  execute "restart Rails app #{application}" do
    cwd deploy[:current_path]
    command node[:opsworks][:rails_stack][:restart_command]
    action :nothing
  end

  node.default[:deploy][application][:database][:adapter] = OpsWorks::RailsConfiguration.determine_database_adapter(application, node[:deploy][application], "#{node[:deploy][application][:deploy_to]}/current", :force => node[:force_database_adapter_detection])
  deploy = node[:deploy][application]

  template "#{deploy[:deploy_to]}/shared/config/database.yml" do
    source "database.yml.erb"
    cookbook 'rails'
    mode "0660"
    group deploy[:group]
    owner deploy[:user]
    variables(:database => deploy[:database], :environment => deploy[:rails_env])

    notifies :run, "execute[restart Rails app #{application}]"

    only_if do
      deploy[:database][:host].present? && File.directory?("#{deploy[:deploy_to]}/shared/config/")
    end
  end

  template "#{deploy[:deploy_to]}/shared/config/memcached.yml" do
    source "memcached.yml.erb"
    cookbook 'rails'
    mode "0660"
    group deploy[:group]
    owner deploy[:user]
    variables(
      :memcached => deploy[:memcached] || {},
      :environment => deploy[:rails_env]
    )

    notifies :run, "execute[restart Rails app #{application}]"

    only_if do
      deploy[:memcached][:host].present? && File.directory?("#{deploy[:deploy_to]}/shared/config/")
    end
  end

  if deploy.has_key?(:puma)
    template "#{deploy[:deploy_to]}/shared/config/application.yml" do
      mode 0644
      owner deploy[:user]
      group deploy[:group]
      source "application.yml.erb"
      variables(
        env: OpsWorks::Escape.escape_double_quotes(deploy[:environment_variables])
        )
      not_if { deploy[:environment_variables] == {} or deploy[:environment_variables] == nil }
    end
  end
end