/*
 Copyright 2017-present The Material Motion Authors. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import XCTest

#if IS_BAZEL_BUILD
import _MotionAnimator
#else
import MotionAnimator
#endif

// A headless layer is one without a delegate. UIView's backing CALayer instance automatically sets
// its delegate to the UIView, but CALayer instances created on their own have no delegate. These
// tests validate our expectations for how headless layers should behave both with and without our
// motion animator support.
class HeadlessLayerImplicitAnimationTests: XCTestCase {

  var window: UIWindow!
  override func setUp() {
    super.setUp()

    window = UIWindow()
    window.makeKeyAndVisible()
  }

  override func tearDown() {
    window = nil

    super.tearDown()
  }

  func testViewDoesImplicitlyAnimateInUIViewAnimateBlock() {
    let view = UIView()
    UIView.animate(withDuration: CATransaction.animationDuration() + 0.1) {
      view.alpha = 0.5
    }

    XCTAssert(view.layer.animation(forKey: "opacity") is CABasicAnimation)
    if let animation = view.layer.animation(forKey: "opacity") as? CABasicAnimation {
      XCTAssertEqual(animation.keyPath, "opacity")
      XCTAssertEqual(animation.duration, CATransaction.animationDuration() + 0.1)
    }
  }

  func testViewLayerDoesImplicitlyAnimateInUIViewAnimateBlock() {
    let view = UIView()
    UIView.animate(withDuration: CATransaction.animationDuration() + 0.1) {
      view.layer.opacity = 0.5
    }

    XCTAssert(view.layer.animation(forKey: "opacity") is CABasicAnimation)
    if let animation = view.layer.animation(forKey: "opacity") as? CABasicAnimation {
      XCTAssertEqual(animation.keyPath, "opacity")
      XCTAssertEqual(animation.duration, CATransaction.animationDuration() + 0.1)
    }
  }

  func testViewDoesNotImplicitlyAnimate() {
    let view = UIView()
    view.alpha = 0.5

    XCTAssertNil(view.layer.animationKeys())
  }

  func testViewLayerDoesNotImplicitlyAnimate() {
    let view = UIView()
    view.layer.opacity = 0.5

    XCTAssertNil(view.layer.animationKeys())
  }

  func testUnFlushedLayerDoesNotImplicitlyAnimate() {
    let unflushedLayer = CALayer()
    unflushedLayer.opacity = 0.5

    XCTAssertNil(unflushedLayer.animationKeys())
  }

  func testDoesImplicitlyAnimate() {
    let layer = CALayer()
    window.layer.addSublayer(layer)
    RunLoop.main.run(mode: .defaultRunLoopMode, before: .distantFuture)

    layer.opacity = 0.5

    XCTAssert(layer.animation(forKey: "opacity") is CABasicAnimation)
    if let animation = layer.animation(forKey: "opacity") as? CABasicAnimation {
      XCTAssertEqual(animation.keyPath, "opacity")
      XCTAssertEqual(animation.duration, CATransaction.animationDuration())
    }
  }

  func testImplicitlyAnimatesInUIViewAnimateBlockWithCATransactionDuration() {
    let layer = CALayer()
    window.layer.addSublayer(layer)
    CATransaction.flush()
    UIView.animate(withDuration: 0.8, animations: {
      layer.opacity = 0.5
    })

    XCTAssert(layer.animation(forKey: "opacity") is CABasicAnimation)
    if let animation = layer.animation(forKey: "opacity") as? CABasicAnimation {
      XCTAssertEqual(animation.keyPath, "opacity")
      XCTAssertEqual(animation.duration, CATransaction.animationDuration())
    }
  }

  func testDoesNotImplicitlyAnimateInCATransactionWithActionsDisabled() {
    let layer = CALayer()
    window.layer.addSublayer(layer)
    CATransaction.flush()

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.opacity = 0.5
    CATransaction.commit()

    XCTAssertNil(layer.animationKeys())
  }

  func testCATransactionTimingTakesPrecedenceOverUIViewTimingInside() {
    let layer = CALayer()
    window.layer.addSublayer(layer)
    CATransaction.flush()

    UIView.animate(withDuration: 0.5) {
      layer.opacity = 0.5
    }

    XCTAssert(layer.animation(forKey: "opacity") is CABasicAnimation)
    if let animation = layer.animation(forKey: "opacity") as? CABasicAnimation {
      XCTAssertEqual(animation.keyPath, "opacity")
      XCTAssertEqual(animation.duration, CATransaction.animationDuration())
    }
  }

  // Verifies the somewhat counter-intuitive fact that CATransaction's animation duration always
  // takes precedence over UIView's animation duration. This means that animating a headless layer
  // using UIView animation APIs may not result in the expected traits.
  func testCATransactionTimingTakesPrecedenceOverUIViewTimingOutside() {
    let layer = CALayer()
    window.layer.addSublayer(layer)
    CATransaction.flush()

    UIView.animate(withDuration: CATransaction.animationDuration() + 0.1) {
      layer.opacity = 0.5
    }

    XCTAssert(layer.animation(forKey: "opacity") is CABasicAnimation)
    if let animation = layer.animation(forKey: "opacity") as? CABasicAnimation {
      XCTAssertEqual(animation.keyPath, "opacity")
      XCTAssertEqual(animation.duration, CATransaction.animationDuration())
    }
  }

  func testDoesImplicitlyAnimateInUIViewAnimateBlock() {
    let layer = CALayer()
    window.layer.addSublayer(layer)
    CATransaction.flush()

    UIView.animate(withDuration: CATransaction.animationDuration() + 0.1) {
      layer.opacity = 0.5
    }

    XCTAssert(layer.animation(forKey: "opacity") is CABasicAnimation)
    if let animation = layer.animation(forKey: "opacity") as? CABasicAnimation {
      XCTAssertEqual(animation.keyPath, "opacity")
      XCTAssertEqual(animation.duration, CATransaction.animationDuration())
    }
  }

  func testDoesImplicitlyAnimateInUIViewAnimateBlockWhenLayerIsASublayerOfAView() {
    let view = UIView()
    window.addSubview(view)
    let layer = CALayer()
    view.layer.addSublayer(layer)
    CATransaction.flush()

    UIView.animate(withDuration: CATransaction.animationDuration() + 0.1) {
      layer.opacity = 0.5
    }

    XCTAssert(layer.animation(forKey: "opacity") is CABasicAnimation)
    if let animation = layer.animation(forKey: "opacity") as? CABasicAnimation {
      XCTAssertEqual(animation.keyPath, "opacity")
      XCTAssertEqual(animation.duration, CATransaction.animationDuration())
    }
  }

  func testDoesImplicitlyAnimateWhenLayerIsASublayerOfAView() {
    let view = UIView()
    window.addSubview(view)
    let layer = CALayer()
    view.layer.addSublayer(layer)
    CATransaction.flush()

    layer.opacity = 0.5

    XCTAssert(layer.animation(forKey: "opacity") is CABasicAnimation)
    if let animation = layer.animation(forKey: "opacity") as? CABasicAnimation {
      XCTAssertEqual(animation.keyPath, "opacity")
      XCTAssertEqual(animation.duration, CATransaction.animationDuration())
    }
  }

  func testDoesNotImplicitlyAnimateInUIViewAnimateBlockWithActionsDisabledInside() {
    let layer = CALayer()
    window.layer.addSublayer(layer)
    CATransaction.flush()

    UIView.animate(withDuration: 0.5) {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      layer.opacity = 0.5
      CATransaction.commit()
    }

    XCTAssertNil(layer.animationKeys())
  }

  func testDoesNotImplicitlyAnimateInUIViewAnimateBlockWithActionsDisabledOutside() {
    let layer = CALayer()
    window.layer.addSublayer(layer)
    CATransaction.flush()

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    UIView.animate(withDuration: 0.5) {
      layer.opacity = 0.5
    }
    CATransaction.commit()

    XCTAssertNil(layer.animationKeys())
  }

  func testAnimationTraitsTakesPrecedenceOverCATransactionTiming() {
    let layer = CALayer()
    window.layer.addSublayer(layer)
    CATransaction.flush()

    let animator = MotionAnimator()
    animator.additive = false

    let traits = MDMAnimationTraits(duration: 1)

    CATransaction.begin()
    CATransaction.setAnimationDuration(0.5)
    animator.animate(with: traits) {
      layer.opacity = 0.5
    }
    CATransaction.commit()

    XCTAssert(layer.animation(forKey: "opacity") is CABasicAnimation)
    if let animation = layer.animation(forKey: "opacity") as? CABasicAnimation {
      XCTAssertEqual(animation.keyPath, "opacity")
      XCTAssertEqual(animation.duration, traits.duration)
    }
  }

  // MARK: Deprecated tests.

  @available(*, deprecated)
  func testDoesImplicitlyAnimateInCATransactionWithLayerDelegateAlone() {
    let layer = CALayer()
    window.layer.addSublayer(layer)
    CATransaction.flush()

    layer.delegate = MotionAnimator.sharedLayerDelegate()

    CATransaction.begin()
    CATransaction.setAnimationDuration(0.5)
    layer.opacity = 0.5
    CATransaction.commit()

    XCTAssertEqual(layer.animationKeys()!, ["opacity"])
  }

  @available(*, deprecated)
  func testDoesNotImplicitlyAnimateInCATransactionWithLayerDelegateAloneAndActionsAreDisabled() {
    let layer = CALayer()
    window.layer.addSublayer(layer)
    CATransaction.flush()

    layer.delegate = MotionAnimator.sharedLayerDelegate()

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.opacity = 0.5
    CATransaction.commit()

    XCTAssertNil(layer.animationKeys())
  }

  @available(*, deprecated)
  func testDoesImplicitlyAnimateInUIViewAnimateBlockWithLayerDelegateAlone() {
    let layer = CALayer()
    window.layer.addSublayer(layer)
    CATransaction.flush()

    layer.delegate = MotionAnimator.sharedLayerDelegate()

    UIView.animate(withDuration: 0.5) {
      layer.opacity = 0.5
    }

    XCTAssertEqual(layer.animationKeys()!, ["opacity"])
  }

  @available(*, deprecated)
  func testDoesImplicitlyAnimateWithLayerDelegateAndAnimator() {
    let layer = CALayer()
    window.layer.addSublayer(layer)
    CATransaction.flush()

    layer.delegate = MotionAnimator.sharedLayerDelegate()

    let animator = MotionAnimator()
    animator.additive = false
    let traits = MDMAnimationTraits(duration: 1)

    animator.animate(with: traits) {
      layer.opacity = 0.5
    }

    XCTAssertEqual(layer.animationKeys()!, ["opacity"])
  }
}
