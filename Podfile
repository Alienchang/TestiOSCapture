platform :ios, '11.0'
#use_frameworks!    去掉后，pod编译为静态库

inhibit_all_warnings!
use_modular_headers!

source 'https://github.com/CocoaPods/Specs.git'

def shared_pods
#  pod 'OpenCV'
end

target 'TestCapture' do
    shared_pods
end


post_install do |installer|
  # 解决xcode 14 报error:“igning for “xxxxx” requires a development team. Select a development team in the Signing & Capabilities editor.”
   installer.generated_projects.each do |project|
      project.targets.each do |target|
          target.build_configurations.each do |config|
              config.build_settings["DEVELOPMENT_TEAM"] = "NYZGNQ3MX8"
           end
      end
    end
   
    installer.pods_project.targets.each do |pod_target|
      pod_target.build_configurations.each do |config|
        config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
        config.build_settings['ENABLE_BITCODE'] = 'NO'
        # pod 中添加与主工程一样预编译宏
      end
    end
end
