Pod::Spec.new do |spec|
  CR_ROOT = 'Sources/CrashReporting/KSCrash/Source/KSCrash'
  spec.name         = "Statsig"
  spec.version      = "1.17.0"
  spec.summary      = "Statsig enables developers to ship code faster and more safely."
  spec.description  = <<-DESC
                   Statsig enables developers to ship code faster and more safely by providing:
                   - Feature gating so you can control precisely which subset of your users should see a feature,
                     and have complete control over a features' ON and OFF status remotely without code changes.
                   - Dynamic Configs so you can change the values of your button colors, font sizes, labels and etc.
                     any time you want, for a subset of users or all of them.
                   - Custom event logging so you can track how your critical metrics move with your product launches,
                     and also run A/B tests to understand whether a new feature actually helps your product before shipping.
                   DESC

  spec.homepage     = "https://github.com/statsig-io/ios-sdk"

  spec.license      = { :type => "ISC", :file => "LICENSE" }

  spec.author             = { "Jiakan Wang" => "jkw@statsig.com", "Daniel Loomb" => "daniel@statsig.com" }

  spec.ios.deployment_target = "10.0"

  spec.source       = { :git => "https://github.com/statsig-io/ios-sdk.git", :tag => "v#{spec.version}" }
  spec.source_files  = "Sources/Statsig/**/*.swift"
  spec.dependency 'StatsigInternalObjC'

  spec.swift_version = '5.0'

  spec.default_subspecs = :none

  spec.subspec 'CrashReporting' do |cr_spec|
    cr_spec.compiler_flags = '-fno-optimize-sibling-calls'
    cr_spec.pod_target_xcconfig = {
      'OTHER_SWIFT_FLAGS[config=*]' => '-DSTATSIG_CRASH_REPORTING',
    }
    cr_spec.libraries = 'c++', 'z'
    cr_spec.xcconfig = { 'GCC_ENABLE_CPP_EXCEPTIONS' => 'YES' }
    cr_spec.frameworks = 'Foundation'

    cr_spec.source_files = CR_ROOT+'/Recording/**/*.{h,m,mm,c,cpp}',
      CR_ROOT+'/llvm/**/*.{h,m,mm,c,cpp}',
      CR_ROOT+'/swift/**/*.{h,m,mm,c,cpp,def}',
      CR_ROOT+'/Reporting/Filters/KSCrashReportFilter.h'

    cr_spec.public_header_files = CR_ROOT+'/Recording/KSCrash.h',
      CR_ROOT+'/Recording/KSCrashC.h',
      CR_ROOT+'/Recording/KSCrashReportWriter.h',
      CR_ROOT+'/Recording/KSCrashReportFields.h',
      CR_ROOT+'/Recording/Monitors/KSCrashMonitorType.h',
      CR_ROOT+'/Reporting/Filters/KSCrashReportFilter.h'
  end

  spec.test_spec 'Tests' do |test_spec|
      test_spec.source_files = 'Tests/StatsigTests/**/*.{swift}'
      test_spec.dependency 'Nimble'
      test_spec.dependency 'Quick'
      test_spec.dependency 'OHHTTPStubs'
      test_spec.dependency 'OHHTTPStubs/Swift'
  end
end
