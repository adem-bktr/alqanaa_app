# This file is part of Flutter and is used to help integrate Flutter with CocoaPods.
# It should not be modified manually.

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', '..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "Generated.xcconfig not found. [!] Build your project with 'flutter build ios' or 'flutter run' to generate it."
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/\AFLUTTER_ROOT=(.*)\z/)
    return matches[1] if matches
  end
  raise "FLUTTER_ROOT not found in Generated.xcconfig. [!] Build your project with 'flutter build ios' or 'flutter run' to generate it."
end

def flutter_install_all_ios_pods(ios_application_path = nil)
  flutter_install_ios_engine_pod(ios_application_path)
  flutter_install_ios_plugin_pods(ios_application_path)
end

def flutter_install_ios_engine_pod(ios_application_path = nil)
  ios_application_path ||= File.dirname(File.expand_path('..', __FILE__))
  engine_dir = File.expand_path('engine', File.dirname(__FILE__))
  if File.exist?(File.join(engine_dir, 'Flutter.podspec'))
    pod 'Flutter', :path => engine_dir
  else
    pod 'Flutter', :podspec => File.join(flutter_root, 'bin', 'cache', 'artifacts', 'engine', 'ios', 'Flutter.podspec')
  end
end

def flutter_install_ios_plugin_pods(ios_application_path = nil)
  ios_application_path ||= File.dirname(File.expand_path('..', __FILE__))
  plugins_file = File.join(ios_application_path, '..', '.flutter-plugins-dependencies')
  unless File.exist?(plugins_file)
    return
  end

  helper_dir = File.expand_path(File.join('..', '..', '.dart_tool', 'flutter_build', 'dart_plugin_registrant'), ios_application_path)
  if File.exist?(helper_dir)
    pod 'FlutterMacOS', :path => helper_dir if target_is_macos?
    pod 'Flutter', :path => helper_dir unless target_is_macos?
  end

  plugins_dependencies = JSON.parse(File.read(plugins_file))
  plugins_dependencies['plugins']['ios'].each do |plugin|
    pod plugin['name'], :path => plugin['path']
  end
end

def flutter_additional_ios_build_settings(target)
  return unless target.respond_to?(:build_configurations)
  target.build_configurations.each do |config|
    config.build_settings['ENABLE_BITCODE'] = 'NO'
  end
end
