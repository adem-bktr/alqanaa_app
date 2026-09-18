# This file is part of Flutter and is used to help integrate Flutter with CocoaPods.
# Polished version for CI/CD environments.

def flutter_root
  # ✅ أولاً: التحقق من وجود المتغير في بيئة السيرفر (Codemagic/GitHub)
  return ENV['FLUTTER_ROOT'] if ENV['FLUTTER_ROOT']

  # ✅ ثانياً: محاولة القراءة من ملف الإعدادات المولد
  generated_xcode_build_settings_path = File.expand_path(File.join('..', '..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  if File.exist?(generated_xcode_build_settings_path)
    File.foreach(generated_xcode_build_settings_path) do |line|
      matches = line.match(/\AFLUTTER_ROOT=(.*)\z/)
      return matches[1] if matches
    end
  end

  # ✅ ثالثاً: إذا فشل كل شيء، نطلق الخطأ
  raise "FLUTTER_ROOT not found. [!] Build your project with 'flutter build ios' to generate it."
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
  return unless File.exist?(plugins_file)

  helper_dir = File.expand_path(File.join('..', '..', '.dart_tool', 'flutter_build', 'dart_plugin_registrant'), ios_application_path)
  if File.exist?(helper_dir)
    pod 'Flutter', :path => helper_dir
  end

  require 'json'
  plugins_dependencies = JSON.parse(File.read(plugins_file))
  plugins_dependencies['plugins']['ios'].each do |plugin|
    pod plugin['name'], :path => plugin['path']
  end
rescue => e
  puts "⚠️ Warning: Failed to install plugin pods: #{e}"
end

def flutter_additional_ios_build_settings(target)
  return unless target.respond_to?(:build_configurations)
  target.build_configurations.each do |config|
    config.build_settings['ENABLE_BITCODE'] = 'NO'
  end
end
