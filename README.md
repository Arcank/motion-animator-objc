![Motion Animator Banner](img/motion-animator-banner.gif)

> An animator for iOS 8+ that combines the best aspects of modern UIView and CALayer animation APIs.

[![Build Status](https://travis-ci.org/material-motion/motion-animator-objc.svg?branch=develop)](https://travis-ci.org/material-motion/motion-animator-objc)
[![codecov](https://codecov.io/gh/material-motion/motion-animator-objc/branch/develop/graph/badge.svg)](https://codecov.io/gh/material-motion/motion-animator-objc)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/MotionAnimator.svg)](https://cocoapods.org/pods/MotionAnimator)
[![Platform](https://img.shields.io/cocoapods/p/MotionAnimator.svg)](http://cocoadocs.org/docsets/MotionAnimator)

## Background on iOS animation systems

Animation systems on iOS can be split in to two general categories: main thread-based and render server-based.

Main thread-based animation systems include UIDynamics, Facebook's [POP](https://github.com/facebook/pop), or anything driven by a CADisplayLink. These animation systems tend to require that you offload as much processing time as possible to background threads, otherwise your animations may stutter; i.e. "*main thread jank*".

There is one render server-based animation system: Core Animation. The *render server* is an operating system-wide process for animations on iOS. Because it's independent of any app's main thread, the render server is never subject to main thread jank.

When evaluating whether to use a main thread-based animation system or not, check first whether the same animations can be performed in Core Animation instead. If they can, you may be able to offload the animations from your app's main thread.

## The MotionAnimator as a generalized render server animation API

There are two primary ways to add animations to the render server: **explicitly**, using the CALayer `addAnimation:forKey:` APIs; and **implicitly**, using with the UIView `animateWithDuration:` APIs and by setting properties on standalone CALayer instances. There are a large number of differences between these two APIs and understanding their relative merits is an important part of harnessing iOS' render server.

The differences can be grouped into answers to the following questions:

1. What properties can I explicitly animate?
2. What properties can I implicitly animate?
3. Are animations additive by default? In other words, can animations change their destination mid-way through the animation while still preserving momentum?

We'll answer each of these questions using a chart that compares the four different mechanisms for animating views and layers on iOS:

1. CALayer explicit `addAnimation:forKey:`
2. UIView implicit `animateWithDuration:`
3. CALayer implicit `layer.<property> = <someNewValue>`
4. MotionAnimator

### What properties can I explicitly animate?

The only explicit animation API is CALayer's `addAnimation:forKey:`. Everything ultimately funnels down to this method whether you're animating a UIView or a CALayer.

> For a full list of animatable CALayer properties, see the [Apple documentation](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/CoreAnimation_guide/AnimatableProperties/AnimatableProperties.html).

Any property that can be animated explicitly with CALayer's `addAnimation:forKey:` can also be animated explicitly using the MotionAnimator's `animateWithTraits:` APIs:

```swift
let animation = CABasicAnimation(keyPath: "cornerRadius")
animation.fromValue = 0
animation.toValue = 10
animation.duration = 0.5
view.layer.add(animation, forKey: animation.keyPath)

// ^ is equivalent to:

let animator = MotionAnimator()
let traits = MDMAnimationTraits(duration: 0.5)
animator.animate(with: traits,
                 between: [0, 10],
                 layer: view.layer,
                 keyPath: .cornerRadius)

// Note that keyPath is an enum string type, so you can also pass arbitrary key paths
// like so:
animator.animate(with: traits,
                 between: [0, 10],
                 layer: view.layer,
                 keyPath: AnimatableKeyPath(rawValue: "customKeyPath"))
```

### What properties can I implicitly animate?

UIKit and Core Animation have different rules about when and how a property can be implicitly animated.

UIView properties generate implicit animations **only** when they are changed within an `animateWithDuration:` animation block.

CALayer properties generate implicit animations **only** when they are changed under the following conditions:

1. The CALayer is backing a UIView, the property is a supported UIKit animatable property (this is not documented anywhere), and the properties are being changed within an `animateWithDuration:` block.
2. The CALayer is **not** backing a UIView (a "standalone layer"), the layer has been around for at least one CATransaction flush (either by invoking `CATransaction.flush()` or because the run loop turned), and the property is changed.

This behavior can be somewhat difficult to reason through, most notably when trying to animate CALayer properties using the UIView `animateWithDuration:` APIs. For example, CALayer's cornerRadius was not animatable using `animateWithDuration:` up until iOS 11, but MotionAnimator supports imlicitly animating this property back to iOS 8.

```swift
// This doesn't work until iOS 11.
UIView.animate(withDuration: 0.8, animations: {
  view.layer.borderWidth = 10
}, completion: nil)

// This works all the way back to iOS 8.
MotionAnimator.animate(withDuration: 0.8, animations: {
  view.layer.borderWidth = 10
}, completion: nil)
```

The MotionAnimator provides a more consistent implicit animation API with a well-defined set of supported properties.

#### When will changing a property cause an implicit animation?

The following charts describe when changing a property on a given object will cause an implicit animation to be generated.

#### UIView

| Key Path               | inside animation block | outside animation block | inside MotionAnimator animation block |
|:-----------------------|:-----------------------|:------------------------|:--------------------------------------|
| `alpha`                | ✓                      |                         | ✓                                     |
| `backgroundColor`      | ✓                      |                         | ✓                                     |
| `bounds`               | ✓                      |                         | ✓                                     |
| `bounds.size.height`   | ✓                      |                         | ✓                                     |
| `bounds.size.width`    | ✓                      |                         | ✓                                     |
| `center`               | ✓                      |                         | ✓                                     |
| `center.x`             | ✓                      |                         | ✓                                     |
| `center.y`             | ✓                      |                         | ✓                                     |
| `transform`            | ✓                      |                         | ✓                                     |
| `transform.rotation.z` | ✓                      |                         | ✓                                     |
| `transform.scale`      | ✓                      |                         | ✓                                     |

Example code:

```
let view = UIView()

// inside animation block
UIView.animate(withDuration: 0.8, animations: {
  view.alpha = 0.5
})

// outside animation block
view.alpha = 0.5

// inside MotionAnimator animation block
MotionAnimator.animate(withDuration: 0.8, animations: {
  view.alpha = 0.5
})
```

#### Backing CALayer

| Key Path                       | inside animation block | outside animation block | inside MotionAnimator animation block |
|:-------------------------------|:-----------------------|:------------------------|:--------------------------------------|
| `anchorPoint`                  | ✓                      |                         | ✓                                     |
| `backgroundColor`              |                        |                         | ✓                                     |
| `bounds`                       | ✓                      |                         | ✓                                     |
| `borderWidth`                  |                        |                         | ✓                                     |
| `borderColor`                  |                        |                         | ✓                                     |
| `cornerRadius`                 | ✓ (starting in iOS 11) |                         | ✓                                     |
| `bounds.size.height`           | ✓                      |                         | ✓                                     |
| `opacity`                      | ✓                      |                         | ✓                                     |
| `position`                     | ✓                      |                         | ✓                                     |
| `transform.rotation.z`         | ✓                      |                         | ✓                                     |
| `transform.scale`              | ✓                      |                         | ✓                                     |
| `shadowColor`                  |                        |                         | ✓                                     |
| `shadowOffset`                 |                        |                         | ✓                                     |
| `shadowOpacity`                |                        |                         | ✓                                     |
| `shadowRadius`                 |                        |                         | ✓                                     |
| `strokeStart`                  |                        |                         | ✓                                     |
| `strokeEnd`                    |                        |                         | ✓                                     |
| `transform`                    | ✓                      |                         | ✓                                     |
| `bounds.size.width`            | ✓                      |                         | ✓                                     |
| `position.x`                   | ✓                      |                         | ✓                                     |
| `position.y`                   | ✓                      |                         | ✓                                     |
| `zPosition`                    |                        |                         | ✓                                     |

Example code:

```
let view = UIView()

// inside animation block
UIView.animate(withDuration: 0.8, animations: {
  view.layer.opacity = 0.5 // Note: will animate with the CATransaction duration of 0.25 rather than 0.8.
})

// outside animation block
view.layer.opacity = 0.5

// inside MotionAnimator animation block
MotionAnimator.animate(withDuration: 0.8, animations: {
  view.layer.opacity = 0.5 // Note: will animate with the provided duration of 0.8
})
```

#### Unflushed standalone CALayer

| Key path                       | inside animation block | outside animation block | inside MotionAnimator animation block |
|:-------------------------------|:-----------------------|:------------------------|:--------------------------------------|
| `anchorPoint`                  |                        |                         | ✓                                     |
| `backgroundColor`              |                        |                         | ✓                                     |
| `bounds`                       |                        |                         | ✓                                     |
| `borderWidth`                  |                        |                         | ✓                                     |
| `borderColor`                  |                        |                         | ✓                                     |
| `cornerRadius`                 |                        |                         | ✓                                     |
| `bounds.size.height`           |                        |                         | ✓                                     |
| `opacity`                      |                        |                         | ✓                                     |
| `position`                     |                        |                         | ✓                                     |
| `transform.rotation.z`         |                        |                         | ✓                                     |
| `transform.scale`              |                        |                         | ✓                                     |
| `shadowColor`                  |                        |                         | ✓                                     |
| `shadowOffset`                 |                        |                         | ✓                                     |
| `shadowOpacity`                |                        |                         | ✓                                     |
| `shadowRadius`                 |                        |                         | ✓                                     |
| `strokeStart`                  |                        |                         | ✓                                     |
| `strokeEnd`                    |                        |                         | ✓                                     |
| `transform`                    |                        |                         | ✓                                     |
| `bounds.size.width`            |                        |                         | ✓                                     |
| `position.x`                   |                        |                         | ✓                                     |
| `position.y`                   |                        |                         | ✓                                     |
| `zPosition`                    |                        |                         | ✓                                     |

Example code:

```
let layer = CALayer()

// inside animation block
UIView.animate(withDuration: 0.8, animations: {
  layer.opacity = 0.5
})

// outside animation block
layer.opacity = 0.5

// inside MotionAnimator animation block
MotionAnimator.animate(withDuration: 0.8, animations: {
  layer.opacity = 0.5
})
```

#### Flushed standalone CALayer

| Key path                       | inside animation block | outside animation block | inside MotionAnimator animation block |
|:-------------------------------|:-----------------------|:------------------------|:--------------------------------------|
| `anchorPoint`                  | ✓                      | ✓                       | ✓                                     |
| `backgroundColor`              |                        |                         | ✓                                     |
| `bounds`                       | ✓                      | ✓                       | ✓                                     |
| `borderWidth`                  | ✓                      | ✓                       | ✓                                     |
| `borderColor`                  | ✓                      | ✓                       | ✓                                     |
| `cornerRadius`                 | ✓                      | ✓                       | ✓                                     |
| `bounds.size.height`           | ✓                      | ✓                       | ✓                                     |
| `opacity`                      | ✓                      | ✓                       | ✓                                     |
| `position`                     | ✓                      | ✓                       | ✓                                     |
| `transform.rotation.z`         | ✓                      | ✓                       | ✓                                     |
| `transform.scale`              | ✓                      | ✓                       | ✓                                     |
| `shadowColor`                  | ✓                      | ✓                       | ✓                                     |
| `shadowOffset`                 | ✓                      | ✓                       | ✓                                     |
| `shadowOpacity`                | ✓                      | ✓                       | ✓                                     |
| `shadowRadius`                 | ✓                      | ✓                       | ✓                                     |
| `strokeStart`                  | ✓                      | ✓                       | ✓                                     |
| `strokeEnd`                    | ✓                      | ✓                       | ✓                                     |
| `transform`                    | ✓                      | ✓                       | ✓                                     |
| `bounds.size.width`            | ✓                      | ✓                       | ✓                                     |
| `position.x`                   | ✓                      | ✓                       | ✓                                     |
| `position.y`                   | ✓                      | ✓                       | ✓                                     |
| `zPosition`                    | ✓                      | ✓                       | ✓                                     |

Example code:

```
let layer = CALayer()

// It's usually unnecessary to flush the transaction, unless you want to be able to implicitly
// animate it without using a MotionAnimator.
CATransaction.flush()

// inside animation block
UIView.animate(withDuration: 0.8, animations: {
  layer.opacity = 0.5 // Note: will animate with the CATransaction duration of 0.25 rather than 0.8.
})

// outside animation block
layer.opacity = 0.5

// inside MotionAnimator animation block
MotionAnimator.animate(withDuration: 0.8, animations: {
  layer.opacity = 0.5 // Note: will animate with the provided duration of 0.8
})
```

## WWDC material on Core Animation

- [Building Animation Driven Interfaces](http://asciiwwdc.com/2010/sessions/123)
- [Core Animation in Practice, Part 1](http://asciiwwdc.com/2010/sessions/424)
- [Core Animation in Practice, Part 2](http://asciiwwdc.com/2010/sessions/425)
- [Building Interruptible and Responsive Interactions](http://asciiwwdc.com/2014/sessions/236)
- [Advanced Graphics and Animations for iOS Apps](http://asciiwwdc.com/2014/sessions/419)
- [Advances in UIKit Animations and Transitions](http://asciiwwdc.com/2016/sessions/216)

## Example apps/unit tests

Check out a local copy of the repo to access the Catalog application by running the following
commands:

    git clone https://github.com/material-motion/motion-animator-objc.git
    cd motion-animator-objc
    pod install
    open MotionAnimator.xcworkspace

## Installation

### Installation with CocoaPods

> CocoaPods is a dependency manager for Objective-C and Swift libraries. CocoaPods automates the
> process of using third-party libraries in your projects. See
> [the Getting Started guide](https://guides.cocoapods.org/using/getting-started.html) for more
> information. You can install it with the following command:
>
>     gem install cocoapods

Add `motion-animator` to your `Podfile`:

    pod 'MotionAnimator'

Then run the following command:

    pod install

### Usage

Import the framework:

    @import MotionAnimator;

You will now have access to all of the APIs.

## Guides

- [How to make a spec from existing animations](#how-to-make-a-spec-from-existing-animations)
- [How to animate explicit layer properties](#how-to-animate-explicit-layer-properties)
- [How to animate like UIView](#how-to-animate-like-UIView)
- [How to animate a transition](#how-to-animate-a-transition)
- [How to animate an interruptible transition](#how-to-animate-an-interruptible-transition)

### How to make a spec from existing animations

A *motion spec* is a complete representation of the motion curves that meant to be applied during an
animation. Your motion spec might consist of a single `MDMMotionTiming` instance, or it might be a
nested structure of `MDMMotionTiming` instances, each representing motion for a different part of a
larger animation. In either case, your magic motion constants now have a place to live.

Consider a simple example of animating a view on and off-screen. Without a spec, our code might look
like so:

```objc
CGPoint before = dismissing ? onscreen : offscreen;
CGPoint after = dismissing ? offscreen : onscreen;
view.center = before;
[UIView animateWithDuration:0.5 animations:^{
  view.center = after;
}];
```

What if we want to change this animation to use a spring curve instead of a cubic bezier? To do so
we'll need to change our code to use a new API:

```objc
CGPoint before = dismissing ? onscreen : offscreen;
CGPoint after = dismissing ? offscreen : onscreen;
view.center = before;
[UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0 options:0 animations:^{
  view.center = after;
} completion:nil];
```

Now let's say we wrote the same code with a motion spec and animator:

```objc
MDMMotionTiming motionSpec = {
  .duration = 0.5, .curve = MDMMotionCurveMakeSpring(1, 100, 1),
};

MDMMotionAnimator *animator = [[MDMMotionAnimator alloc] init];
animator.shouldReverseValues = dismissing;
view.center = offscreen;
[_animator animateWithTiming:kMotionSpec animations:^{
  view.center = onscreen;
}];
```

Now if we want to change our motion back to an easing curve, we only have to change the spec:

```objc
MDMMotionTiming motionSpec = {
  .duration = 0.5, .curve = MDMMotionCurveMakeBezier(0.4f, 0.0f, 0.2f, 1.0f),
};
```

The animator code stays the same. It's now possible to modify the motion parameters at runtime
without affecting any of the animation logic.

This pattern is useful for building transitions and animations. To learn more through examples,
see the following implementations:

**Material Components Activity Indicator**

- [Motion spec declaration](https://github.com/material-components/material-components-ios/blob/develop/components/ActivityIndicator/src/private/MDCActivityIndicatorMotionSpec.h)
- [Motion spec definition](https://github.com/material-components/material-components-ios/blob/develop/components/ActivityIndicator/src/private/MDCActivityIndicatorMotionSpec.m)
- [Motion spec usage](https://github.com/material-components/material-components-ios/blob/develop/components/ActivityIndicator/src/MDCActivityIndicator.m#L461)

**Material Components Progress View**

- [Motion spec declaration](https://github.com/material-components/material-components-ios/blob/develop/components/ProgressView/src/private/MDCProgressView%2BMotionSpec.h#L21)
- [Motion spec definition](https://github.com/material-components/material-components-ios/blob/develop/components/ProgressView/src/private/MDCProgressView%2BMotionSpec.m#L19)
- [Motion spec usage](https://github.com/material-components/material-components-ios/blob/develop/components/ProgressView/src/MDCProgressView.m#L155)

**Material Components Masked Transition**

- [Motion spec declaration](https://github.com/material-components/material-components-ios/blob/develop/components/MaskedTransition/src/private/MDCMaskedTransitionMotionSpec.h#L20)
- [Motion spec definition](https://github.com/material-components/material-components-ios/blob/develop/components/MaskedTransition/src/private/MDCMaskedTransitionMotionSpec.m#L23)
- [Motion spec usage](https://github.com/material-components/material-components-ios/blob/develop/components/MaskedTransition/src/MDCMaskedTransition.m#L183)

### How to animate explicit layer properties

`MDMMotionAnimator` provides an explicit API for adding animations to animatable CALayer key paths.
This API is similar to creating a `CABasicAnimation` and adding it to the layer.

```objc
[animator animateWithTiming:timing.chipHeight
                    toLayer:chipView.layer
                 withValues:@[ @(chipFrame.size.height), @(headerFrame.size.height) ]
                    keyPath:MDMKeyPathHeight];
```

### How to animate like UIView

`MDMMotionAnimator` provides an API that is similar to UIView's `animateWithDuration:`. Use this API
when you want to apply the same timing to a block of animations:

```objc
chipView.frame = chipFrame;
[animator animateWithTiming:timing.chipHeight animations:^{
  chipView.frame = headerFrame;
}];
// chipView.layer's position and bounds will now be animated with timing.chipHeight's timing.
```

### How to animate a transition

Start by creating an `MDMMotionAnimator` instance.

```objc
MDMMotionAnimator *animator = [[MDMMotionAnimator alloc] init];
```

When we describe our transition we'll describe it as though we're moving forward and take advantage
of the `shouldReverseValues` property on our animator to handle the reverse direction.

```objc
animator.shouldReverseValues = isTransitionReversed;
```

To animate a property on a view, we invoke the `animate` method. We must provide a timing, values,
and a key path:

```objc
[animator animateWithTiming:timing
                    toLayer:view.layer
                 withValues:@[ @(collapsedHeight), @(expandedHeight) ]
                    keyPath:MDMKeyPathHeight];
```

### How to animate an interruptible transition

`MDMMotionAnimator` is configured by default to generate interruptible animations using Core
Animation's additive animation APIs. You can simply re-execute the `animate` calls when your
transition's direction changes and the animator will add new animations for the updated direction.

## Helpful literature

- [Additive animations: animateWithDuration in iOS 8](http://iosoteric.com/additive-animations-animatewithduration-in-ios-8/)
- [WWDC 2014 video on additive animations](https://developer.apple.com/videos/play/wwdc2014/236/)

## Contributing

We welcome contributions!

Check out our [upcoming milestones](https://github.com/material-motion/motion-animator-objc/milestones).

Learn more about [our team](https://material-motion.github.io/material-motion/team/),
[our community](https://material-motion.github.io/material-motion/team/community/), and
our [contributor essentials](https://material-motion.github.io/material-motion/team/essentials/).

## License

Licensed under the Apache 2.0 license. See LICENSE for details.
