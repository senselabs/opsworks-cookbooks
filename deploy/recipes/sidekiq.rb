include_recipe 'deploy'

node[:deploy].each do |application, deploy|

  unless deploy.has_key?(:sidekiq)
    Chef::Log.debug("Skipping deploy::sidekiq application #{application} as it is not a Sidekiq app")
    next
  end

  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  opsworks_rails do
    deploy_data deploy
    app application
  end

  opsworks_deploy do
    deploy_data deploy
    app application
  end
end
