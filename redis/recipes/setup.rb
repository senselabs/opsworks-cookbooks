include_recipe 'aws'

redis_conf = node[:redis]

aws_s3_file "/home/deploy/#{node[:redis][:package]}.tar.gz" do
	bucket "deploy-dependencies"
	remote_path "#{redis_conf[:package]}.tar.gz"
	aws_access_key_id redis_conf[:s3_access_key]
	aws_secret_access_key redis_conf[:s3_secret_key]
end

bash "install_redis" do
	user "root"
	cwd "/home/deploy"
	code <<-EOH
		tar -zxf #{redis_conf[:package]}.tar.gz
		(cd #{redis_conf[:package]}/ && make && make install)
	EOH
end

template "setup redis-server" do
	path "/etc/init.d/redis-server"
	source "redis-server.erb"
	owner "root"
	group "root"
	mode 0755
	variables({
		server_path: "/usr/local/bin/redis-server",
		config_path: "/etc/redis/redis.conf"
	})
end

template "setup redis.conf" do
	path "/etc/redis/redis.conf"
	source "redis.conf.erb"
	owner "root"
	group "root"
	mode 0644
	variables({
		port: redis_conf[:port],
		bind: redis_conf[:bind]
	})
end

service "redis-server" do
	action :start
end