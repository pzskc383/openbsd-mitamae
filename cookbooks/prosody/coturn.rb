include_recipe "../pf/defines.rb"

package "turnserver"
lines_in_file "/etc/turnserver.conf" do
  lines [
    {
      line: %i[v4 v6].map{ |a| "listening-ip=#{node[:network_setup][a][:address]}" }.append([]).join("\n"),
      regexp: %r{^#listening-ip=.*\n\n}m
    },
    {
      line: %i[v4 v6].map{ |a| "listening-ip=#{node[:network_setup][a][:address]}" }.append([]).join("\n"),
      regexp: %r{^#listening-ip=.*\n\n}m
    },
    "verbose"
  ]
end

service "turnserver" do
  action %i[enable start]
end

ports = [3478, 5349]
protos = %w[tcp udp]
ports.each do |port|
  protos.each do |proto|
    pf_open "#{port}/#{proto}" do
      port port
      proto proto
      label "turn"
    end
  end
end