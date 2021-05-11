# ios-sdk

Statsig SDK for iOS applications written in Swift or Objective-C.

## Getting started

### Adding Statsig as a dependency to your project

To add Statsig as a dependency through Swift Package Manager, in your Xcode, select File > Swift Packages > Add Package Dependency
and enter the URL https://github.com/statsig-io/ios-sdk.

You can also include it directly in your project's Package.swift:

```
//...
dependencies: [
    .package(url: "https://github.com/statsig-io/ios-sdk.git", .upToNextMinor("1.0.9")),
],
//...
targets: [
    .target(
        name: "YOUR_TARGET",
        dependencies: ["Statsig"]
    )
],
//...
```

If you are using CocoaPods, our pod name is 'Statsig', and you can include the following line to your Podfile:

```
use_frameworks!
target 'TargetName' do
  //...
  pod 'Statsig', '~> 1.0.9' // Add this line
end
```

### Using Statsig in your project

Statsig is a singleton class which you can initialize with Statsig.start() function:

```swift
// Swift
Statsig.start(sdkKey: "my_client_sdk_key", user: StatsigUser(userID: "my_user_id"))
```
```objectivec
// Objective-C
StatsigUser *user = [[StatsigUser alloc] initWithUserID:@"my_user_id"];
[Statsig startWithSDKKey:@"my_client_sdk_key", user:user];
```

You can also optionally use a completion block to wait for it to finish initializing:

```swift
// Swift
Statsig.start(sdkKey: "my_client_sdk_key", user: StatsigUser(userID: "my_user_id")) { errorMessage in

  // Statsig client is ready;

  // errorMessage can be used for debugging purposes. Statsig client still functions when errorMessage
  // is present, e.g. when device is offline, either cached or default values will be returned by Statsig APIs.

}
```

```objectivec
// Objective-C
StatsigUser *user = [[StatsigUser alloc] initWithUserID:@"my_user_id"];
[Statsig startWithSDKKey:@"my_client_sdk_key", user:user, completion:^(NSString * errorMessage) {
  // Statsig client is ready
  
  // errorMessage can be used for debugging purposes. Statsig client still functions when errorMessage
  // is present, e.g. when device is offline, either cached or default values will be returned by Statsig APIs.
}];
```

To check the value of a feature gate for the current user, use the checkGate() function. Note that if the gate_name provided does not exist,
or if the device is offline, we will return false as the default value.

```swift
// Swift
let showNewDesign = Statsig.checkGate("show_new_design")
```
```objectivec
// Objective-C
BOOL showNewDesign = [Statsig checkGateForName:@"show_new_design"];
```

To retrieve a Dynamic Config for the current user, use the getConfig() function:

```swift
// Swift
let localizationConfig = Statsig.getConfig("localization_config")
```
```objectivec
// Objective-C
DynamicConfig *localizationConfig = [Statsig getConfigForName:@"localization_config"];
```

which will return a DynamicConfig object that you can then call getValue() on to retrieve specific values within the Dynamic Config. The
defaultValue will be returned when the user if offline or the key does not exist.

```swift
// Swift
let buttonText = localizationConfig.getValue(forKey: "button_text", defaultValue: "Check out")
```
```objectivec
// Objective-C
NSString *buttonText = [config getStringForKey:@"button_text" defaultValue:@""Check out""];
```

Sometimes the logged in user might switch to a different user, or you just received more information about the user and wish to update them,
you can call the updateUser() function to notify Statsig so it can retrieve the correct values for the updated user:

```swift
// Swift
let newUser = StatsigUser(userID: "new_user_id", email: "newUser@gmail.com", country: "US")

Statsig.updateUser(newUser)
```
```objectivec
// Objective-C
StatsigUser *newUser = [[StatsigUser alloc] initWithUserID:@"new_user_id" email:@"newUser@gmail.com" ip:nil country:@"US" custom:custom:@{@"is_new_user": @YES}];
[Statsig updateUserWithNewUser:user completion:nil];
```

You can also use the same optional completion block to be notified when Statsig is done fetching values for the new user, just like in start().

### StatsigUser

The StatsigUser class is what we use to help you with targeting. You can provide _userID_, _email_, _ip_, _country_, and even _custom_, which
is a dictionary of String values for your own choices of targeting criteria. _userID_ is highly recommended, and we will try to use device ID
to identify the same user in the absence of a _userID_. You are also encouraged to provide as much _custom_ info as you know about the
user, all of which can be used by you in our console for feature gating and Dynamic Config's targeting.

### Logging custom events

The logEvent() API can be used to log custom events for your application, which will be shown in your Statsig dashboard and used for
metrics calculation for A/B testing:

```swift
// Swift
Statsig.logEvent("purchase", value: 2.99, metadata: ["item_name": "remove_ads"])
```
```objectivec
// Objective-C
[Statsig logEvent:@"purchase" doubleValue:2.99 metadata:@{@"item_name" : @"remove_ads"}];
```

## Shut down

When your application is shutting down, call shutdown() so we can make sure any event logs are being sent for logging properly and all resources are released.

```swift
// Swift
Statsig.shutdown()
```
```objectivec
// Objective-C
[Statsig shutdown];
```

## What is Statsig?

Statsig helps you move faster with Feature Gates (feature flags) and Dynamic Configs. It also allows you to run A/B tests to validate your new features and understand their impact on your KPIs. If you're new to Statsig, create an account at [statsig.com](https://www.statsig.com).
