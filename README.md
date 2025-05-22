> [!WARNING]
> We renamed this repo from `ios-sdk` to `statsig-kit`. Apps should continue working as expected, but we recommend updating your dependencies: [Guide](https://docs.statsig.com/client/iOS/repo-migration-guide).

## Statsig iOS SDK

The Statsig iOS SDK for single user client environments. It works for both Swift and Objective-C. If you need a SDK for another language or server environment, check out our [other SDKs](https://docs.statsig.com/#sdks).

Statsig helps you move faster with feature gates (feature flags), and/or dynamic configs. It also allows you to run A/B/n tests to validate your new features and understand their impact on your KPIs. If you're new to Statsig, check out our product and create an account at [statsig.com](https://www.statsig.com).

## Getting Started
Check out our [SDK docs](https://docs.statsig.com/client/iosClientSDK) to get started.


## Apple's Privacy Manifest

Following Apple's rules, we've included a Privacy Manifest in the Statsig SDK to explain its basic features. 
Developers will need to fill out their own Privacy Manifest, listing the information they add to the StatsigUser class. 
Important details like UserID and Email should be mentioned, but they aren't included by default because not everyone using the SDK will include these details in their StatsigUser class.

For more on how we use and handle data in our SDK, look at the PrivacyInfo.xcprivacy file. If you need help putting these steps into action in your app, check Apple's official guide on Privacy Manifests at https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_data_use_in_privacy_manifests.
