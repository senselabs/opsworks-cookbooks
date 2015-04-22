define :opsworks_rails do
  deploy = params[:deploy_data]
  application = params[:app]

  include_recipe node[:opsworks][:rails_stack][:recipe]

  # write out memcached.yml
  # template "#{deploy[:deploy_to]}/shared/config/memcached.yml" do
  #   cookbook "rails"
  #   source "memcached.yml.erb"
  #   mode "0660"
  #   owner deploy[:user]
  #   group deploy[:group]
  #   variables(:memcached => (deploy[:memcached] || {}), :environment => deploy[:rails_env])

  #   only_if do
  #     deploy[:memcached][:host].present?
  #   end
  # end

  # write out the environment variables
  template "#{deploy[:deploy_to]}/shared/config/application.yml" do
    cookbook "rails"
    source "application.yml.erb"
    mode "0660"
    owner deploy[:user]
    group deploy[:group]
    variables(env: OpsWorks::Escape.escape_double_quotes(deploy[:environment_variables]))

    only_if do
      deploy.has_key?(:puma)
    end
  end

  # template "#{deploy[:deploy_to]}/shared/config/database.yml" do
  #   cookbook "rails"
  #   source "database.yml.erb"
  #   mode "0660"
  #   owner deploy[:user]
  #   group deploy[:group]
  #   variables(
  #     :database => deploy[:database],
  #     :environment => deploy[:rails_env]
  #     )

  #   only_if do
  #     deploy.has_key?(:puma)
  #   end
  # end

  execute "symlinking subdir mount if necessary" do
    command "rm -f /var/www/#{deploy[:mounted_at]}; ln -s #{deploy[:deploy_to]}/current/public /var/www/#{deploy[:mounted_at]}"
    action :run
    only_if do
      deploy[:mounted_at] && File.exists?("/var/www")
    end
  end

end 
