# This file is part of Flutter and is used to help integrate Flutter with CocoaPods.
# Minimalist version for maximum compatibility with Ruby 3.4/CI.

def flutter_root
  ENV['FLUTTER_ROOT'] || (
    config_path = File.expand_path(File.join('..', '..', 'Flutter', 'Generated.xcconfig'), __FILE__)
    if File.exist?(config_path)
      File.readlines(config_path).each do |line|
        return $1.strip if line =~ /\AFLUTTER_ROOT=(.*)\z/
      end
    end
    raise "FLUTTER_ROOT not found"
  )
end

def flutter_install_all_ios_pods(ios_application_path = nil)
  flutter_install_ios_engine_pod(ios_application_path)
  flutter_install_ios_plugin_pods(ios_application_path)
end

def flutter_install_ios_engine_pod(ios_application_path = nil)
  engine_path = File.expand_path(File.join(flutter_root, 'bin', 'cache', 'artifacts', 'engine', 'ios'))
  # ✅ Use absolute local path to bypass Ruby 3.4 URI validation
  pod 'Flutter', :path => engine_path
end

def flutter_install_ios_plugin_pods(ios_application_path = nil)
  ios_application_path ||= File.dirname(File.expand_path('..', __FILE__))
  plugins_file = File.join(ios_application_path, '..', '.flutter-plugins-dependencies')
  return unless File.exist?(plugins_file)

  require 'json'
  begin
    plugins_dependencies = JSON.parse(File.read(plugins_file))
    if plugins_dependencies['plugins'] && plugins_dependencies['plugins']['ios']
      plugins_dependencies['plugins']['ios'].each do |plugin|
        pod plugin['name'], :path => File.expand_path(plugin['path'], File.join(ios_application_path, '..'))
      end
    end
  rescue => e
    puts "⚠️ Plugin Error: #{e}"
  end
end

def flutter_additional_ios_build_settings(target)
  return unless target.respond_to?(:build_configurations)
  target.build_configurations.each do |config|
    config.build_settings['ENABLE_BITCODE'] = 'NO'
    config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
  end
end
