# This file is part of Flutter and is used to help integrate Flutter with CocoaPods.
# Specialized version to fix URI::BadURIError on Ruby 3.4+ CI environments.

def flutter_root
  # 1. Try environment variable (Standard for CI/CD)
  root = ENV['FLUTTER_ROOT']
  return root if root && !root.empty?

  # 2. Fallback to Generated.xcconfig (Local)
  config_path = File.expand_path(File.join('..', '..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  if File.exist?(config_path)
    File.foreach(config_path) do |line|
      matches = line.match(/\AFLUTTER_ROOT=(.*)\z/)
      return matches[1] if matches
    end
  end

  raise "FLUTTER_ROOT not found. [!] Build your project with 'flutter build ios' to generate it."
end

def flutter_install_all_ios_pods(ios_application_path = nil)
  flutter_install_ios_engine_pod(ios_application_path)
  flutter_install_ios_plugin_pods(ios_application_path)
end

def flutter_install_ios_engine_pod(ios_application_path = nil)
  ios_application_path ||= File.dirname(File.expand_path('..', __FILE__))
  engine_dir = File.expand_path('engine', File.dirname(__FILE__))

  # Standard Flutter engine podspec location
  podspec_path = File.join(flutter_root, 'bin', 'cache', 'artifacts', 'engine', 'ios', 'Flutter.podspec')

  if File.exist?(File.join(engine_dir, 'Flutter.podspec'))
    pod 'Flutter', :path => engine_dir
  else
    # ✅ Fix: Ensure the path is absolute and correctly handled as a local file reference
    pod 'Flutter', :podspec => File.expand_path(podspec_path)
  end
end

def flutter_install_ios_plugin_pods(ios_application_path = nil)
  ios_application_path ||= File.dirname(File.expand_path('..', __FILE__))
  plugins_file = File.join(ios_application_path, '..', '.flutter-plugins-dependencies')
  return unless File.exist?(plugins_file)

  require 'json'
  plugins_dependencies = JSON.parse(File.read(plugins_file))

  if plugins_dependencies['plugins'] && plugins_dependencies['plugins']['ios']
    plugins_dependencies['plugins']['ios'].each do |plugin|
      pod plugin['name'], :path => File.expand_path(plugin['path'], ios_application_path)
    end
  end
rescue => e
  puts "⚠️ Warning: Failed to install plugin pods: #{e}"
end

def flutter_additional_ios_build_settings(target)
  return unless target.respond_to?(:build_configurations)
  target.build_configurations.each do |config|
    config.build_settings['ENABLE_BITCODE'] = 'NO'
    config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
  end
end
