redis_conf = node[:redis]

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
	provider Chef::Provider::Service::Upstart
	supports :status => true, :restart => true, :reload => true
	action :restart
end