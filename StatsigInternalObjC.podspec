Pod::Spec.new do |spec|

  spec.name         = "StatsigInternalObjC"
  spec.version      = "1.17.1"
  spec.summary      = "Statsig enables developers to ship code faster and more safely."
  spec.description  = <<-DESC
                  Statsig enables developers to ship code faster and more safely.
                  -
                  Objective C library for the main Statsig pod.
                   DESC

  spec.homepage     = "https://github.com/statsig-io/ios-sdk"

  spec.license      = { :type => "ISC", :file => "LICENSE" }

  spec.author             = { "Jiakan Wang" => "jkw@statsig.com", "Daniel Loomb" => "daniel@statsig.com" }

  spec.ios.deployment_target = "10.0"
  spec.osx.deployment_target = "10.12"

  spec.source       = { :git => "https://github.com/statsig-io/ios-sdk.git", :tag => "v#{spec.version}" }
  spec.source_files  = "Sources/StatsigInternalObjC/**/*.{h,m}"
end
