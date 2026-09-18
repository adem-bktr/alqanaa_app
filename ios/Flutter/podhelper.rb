# This file is part of Flutter and is used to help integrate Flutter with CocoaPods.
# Specialized version for Ruby 3.4+ and CocoaPods 1.17.0+ compatibility.

def flutter_root
  root = ENV['FLUTTER_ROOT']
  return root if root && !root.empty?

  config_path = File.expand_path(File.join('..', '..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  if File.exist?(config_path)
    File.foreach(config_path) do |line|
      matches = line.match(/\AFLUTTER_ROOT=(.*)\z/)
      return matches[1] if matches
    end
  end
  raise "FLUTTER_ROOT not found."
end

def flutter_install_all_ios_pods(ios_application_path = nil)
  flutter_install_ios_engine_pod(ios_application_path)
  flutter_install_ios_plugin_pods(ios_application_path)
end

def flutter_install_ios_engine_pod(ios_application_path = nil)
  podspec_path = File.expand_path(File.join(flutter_root, 'bin', 'cache', 'artifacts', 'engine', 'ios', 'Flutter.podspec'))

  # ✅ Fix for URI::BadURIError: Use explicit file:// scheme for Ruby 3.4 compatibility
  pod 'Flutter', :podspec => "file://#{podspec_path}"
end

def flutter_install_ios_plugin_pods(ios_application_path = nil)
  ios_application_path ||= File.dirname(File.expand_path('..', __FILE__))
  plugins_file = File.join(ios_application_path, '..', '.flutter-plugins-dependencies')
  return unless File.exist?(plugins_file)

  require 'json'
  plugins_dependencies = JSON.parse(File.read(plugins_file))

  if plugins_dependencies['plugins'] && plugins_dependencies['plugins']['ios']
    plugins_dependencies['plugins']['ios'].each do |plugin|
      # ✅ Use explicit file:// scheme for plugins too
      plugin_podspec = File.expand_path(File.join(plugin['path'], 'ios', "#{plugin['name']}.podspec"))
      if File.exist?(plugin_podspec)
        pod plugin['name'], :podspec => "file://#{plugin_podspec}"
      else
        pod plugin['name'], :path => plugin['path']
      end
    end
  end
rescue => e
  puts "⚠️ Warning: #{e}"
end

def flutter_additional_ios_build_settings(target)
  return unless target.respond_to?(:build_configurations)
  target.build_configurations.each do |config|
    config.build_settings['ENABLE_BITCODE'] = 'NO'
    config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
  end
end
