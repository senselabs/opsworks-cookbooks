unless node[:opsworks][:skip_uninstall_of_other_rails_stack]
  include_recipe "apache2::uninstall"
end

include_recipe "nginx"
include_recipe "unicorn"

# setup Unicorn service per app
node[:deploy].each do |application, deploy|
  if deploy[:application_type] != 'rails'
    Chef::Log.debug("Skipping unicorn::rails application #{application} as it is not an Rails app")
    next
  end

  opsworks_deploy_user do
    deploy_data deploy
  end

  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  unless deploy.has_key?(:puma)
    template "#{deploy[:deploy_to]}/shared/scripts/unicorn" do
      mode '0755'
      owner deploy[:user]
      group deploy[:group]
      source "unicorn.service.erb"
      variables(:deploy => deploy, :application => application)
    end

    service "unicorn_#{application}" do
      start_command "#{deploy[:deploy_to]}/shared/scripts/unicorn start"
      stop_command "#{deploy[:deploy_to]}/shared/scripts/unicorn stop"
      restart_command "#{deploy[:deploy_to]}/shared/scripts/unicorn restart"
      status_command "#{deploy[:deploy_to]}/shared/scripts/unicorn status"
      action :nothing
    end

    template "#{deploy[:deploy_to]}/shared/config/unicorn.conf" do
      mode '0644'
      owner deploy[:user]
      group deploy[:group]
      source "unicorn.conf.erb"
      variables(
        :deploy => deploy,
        :application => application,
        :environment => OpsWorks::Escape.escape_double_quotes(deploy[:environment_variables])
      )
    end
  else
    release_path = ::File.join(deploy[:deploy_to], 'current')

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

    link "#{deploy[:deploy_to]}/current/config/application.yml" do
      to "#{deploy[:deploy_to]}/shared/config/application.yml"
    end

    template "setup puma.conf" do
      path "/etc/init/puma-#{application}.conf"
      source "puma.conf.erb"
      owner "root"
      group "root"
      mode 0644
      variables({
        user: deploy[:user],
        group: deploy[:group],
        release_path: release_path
      })
    end

    bash 'precompile_rails_assets' do
      cwd release_path
      user deploy[:user]
      group deploy[:group]
      code <<-EOH
        ls -R > /home/deploy/before.log
        RAILS_ENV=production bundle exec rake assets:precompile > /home/deploy/compile.log
        ls -R > /home/deploy/after.log
      EOH
    end

    service "puma-#{application}" do
      provider Chef::Provider::Service::Upstart
      supports stop: true, start: true, restart: true, status: true
    end

    bash 'restart_puma' do
      code "echo noop"
      notifies :restart, "service[puma-#{application}]"
    end
  end
end
