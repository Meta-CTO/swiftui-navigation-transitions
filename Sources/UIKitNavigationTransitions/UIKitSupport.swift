public import NavigationTransition
import RuntimeAssociation
import RuntimeSwizzling
public import UIKit

public struct UISplitViewControllerColumns: OptionSet {
	public static let primary = Self(rawValue: 1)
	public static let supplementary = Self(rawValue: 1 << 1)
	public static let secondary = Self(rawValue: 1 << 2)

	public static let compact = Self(rawValue: 1 << 3)

	public static let all: Self = [compact, primary, supplementary, secondary]

	public let rawValue: Int8

	public init(rawValue: Int8) {
		self.rawValue = rawValue
	}
}

extension UISplitViewController {
	public func setNavigationTransition(
		_ transition: AnyNavigationTransition,
		forColumns columns: UISplitViewControllerColumns,
		interactivity: AnyNavigationTransition.Interactivity = .default
	) {
		if columns.contains(.compact), let compact = compactViewController as? UINavigationController {
			compact.setNavigationTransition(transition, interactivity: interactivity)
		}
		if columns.contains(.primary), let primary = primaryViewController as? UINavigationController {
			primary.setNavigationTransition(transition, interactivity: interactivity)
		}
		if columns.contains(.supplementary), let supplementary = supplementaryViewController as? UINavigationController {
			supplementary.setNavigationTransition(transition, interactivity: interactivity)
		}
		if columns.contains(.secondary), let secondary = secondaryViewController as? UINavigationController {
			secondary.setNavigationTransition(transition, interactivity: interactivity)
		}
	}
}

extension UISplitViewController {
	var compactViewController: UIViewController? {
		if #available(iOS 14, tvOS 14, *) {
			viewController(for: .compact)
		} else {
			if isCollapsed {
				viewControllers.first
			} else {
				nil
			}
		}
	}

	var primaryViewController: UIViewController? {
		if #available(iOS 14, tvOS 14, *) {
			viewController(for: .primary)
		} else {
			if !isCollapsed {
				viewControllers.first
			} else {
				nil
			}
		}
	}

	var supplementaryViewController: UIViewController? {
		if #available(iOS 14, tvOS 14, *) {
			viewController(for: .supplementary)
		} else {
			if !isCollapsed {
				if viewControllers.count >= 3 {
					viewControllers[safe: 1]
				} else {
					nil
				}
			} else {
				nil
			}
		}
	}

	var secondaryViewController: UIViewController? {
		if #available(iOS 14, tvOS 14, *) {
			viewController(for: .secondary)
		} else {
			if !isCollapsed {
				if viewControllers.count >= 3 {
					viewControllers[safe: 2]
				} else {
					viewControllers[safe: 1]
				}
			} else {
				nil
			}
		}
	}
}

extension RandomAccessCollection where Index == Int {
	subscript(safe index: Index) -> Element? {
		self.dropFirst(index).first
	}
}

extension UINavigationController {
	private var defaultDelegate: (any UINavigationControllerDelegate)! {
		get { self[] }
		set { self[] = newValue }
	}

	var customDelegate: NavigationTransitionDelegate! {
		get { self[] }
		set {
			self[] = newValue
			delegate = newValue
		}
	}

	public func setNavigationTransition(
		_ transition: AnyNavigationTransition,
		interactivity: AnyNavigationTransition.Interactivity = .default
	) {
		if defaultDelegate == nil {
			defaultDelegate = delegate
		}

		if customDelegate == nil {
			customDelegate = NavigationTransitionDelegate(transition: transition, baseDelegate: defaultDelegate)
		} else {
			customDelegate.transition = transition
		}

		swizzle(
			UINavigationController.self,
			#selector(UINavigationController.setViewControllers),
			#selector(UINavigationController.setViewControllers_animateIfNeeded)
		)

		swizzle(
			UINavigationController.self,
			#selector(UINavigationController.pushViewController),
			#selector(UINavigationController.pushViewController_animateIfNeeded)
		)

		swizzle(
			UINavigationController.self,
			#selector(UINavigationController.popViewController),
			#selector(UINavigationController.popViewController_animateIfNeeded)
		)

		swizzle(
			UINavigationController.self,
			#selector(UINavigationController.popToViewController),
			#selector(UINavigationController.popToViewController_animateIfNeeded)
		)

		swizzle(
			UINavigationController.self,
			#selector(UINavigationController.popToRootViewController),
			#selector(UINavigationController.popToRootViewController_animateIfNeeded)
		)

		#if !os(tvOS) && !os(visionOS)
		if defaultEdgePanRecognizer.strongDelegate == nil {
			defaultEdgePanRecognizer.strongDelegate = NavigationGestureRecognizerDelegate(controller: self)
		}

		if defaultPanRecognizer == nil {
			defaultPanRecognizer = UIPanGestureRecognizer()
			defaultPanRecognizer.targets = defaultEdgePanRecognizer.targets // https://stackoverflow.com/a/60526328/1922543
			defaultPanRecognizer.strongDelegate = NavigationGestureRecognizerDelegate(controller: self)
			view.addGestureRecognizer(defaultPanRecognizer)
		}

		if edgePanRecognizer == nil {
			edgePanRecognizer = UIScreenEdgePanGestureRecognizer()
			edgePanRecognizer.edges = .left
			edgePanRecognizer.addTarget(self, action: #selector(handleInteraction))
			edgePanRecognizer.strongDelegate = NavigationGestureRecognizerDelegate(controller: self)
			view.addGestureRecognizer(edgePanRecognizer)
		}

		if panRecognizer == nil {
			panRecognizer = UIPanGestureRecognizer()
			panRecognizer.addTarget(self, action: #selector(handleInteraction))
			panRecognizer.strongDelegate = NavigationGestureRecognizerDelegate(controller: self)
			view.addGestureRecognizer(panRecognizer)
		}

		if transition.isDefault {
			switch interactivity {
			case .disabled:
				exclusivelyEnableGestureRecognizer(.none)
			case .edgePan:
				exclusivelyEnableGestureRecognizer(defaultEdgePanRecognizer)
				// Add target to track native gesture progress
				if !defaultEdgePanRecognizer.hasTarget(self, action: #selector(trackNativeGesture)) {
					defaultEdgePanRecognizer.addTarget(self, action: #selector(trackNativeGesture))
				}
			case .pan:
				exclusivelyEnableGestureRecognizer(defaultPanRecognizer)
				// Add target to track native gesture progress
				if !defaultPanRecognizer.hasTarget(self, action: #selector(trackNativeGesture)) {
					defaultPanRecognizer.addTarget(self, action: #selector(trackNativeGesture))
				}
			}
		} else {
			switch interactivity {
			case .disabled:
				exclusivelyEnableGestureRecognizer(.none)
			case .edgePan:
				exclusivelyEnableGestureRecognizer(edgePanRecognizer)
			case .pan:
				exclusivelyEnableGestureRecognizer(panRecognizer)
			}
		}
		#endif
	}

	@available(tvOS, unavailable)
	@available(visionOS, unavailable)
	private func exclusivelyEnableGestureRecognizer(_ gestureRecognizer: UIPanGestureRecognizer?) {
		for recognizer in [defaultEdgePanRecognizer!, defaultPanRecognizer!, edgePanRecognizer!, panRecognizer!] {
			if let gestureRecognizer, recognizer === gestureRecognizer {
				recognizer.isEnabled = true
			} else {
				recognizer.isEnabled = false
			}
		}
	}
}

extension UINavigationController {
	@objc func trackNativeGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
		guard let delegate = customDelegate,
			  delegate.transition.isDefault,
			  let alongsideHandler = delegate.transition.alongsideHandler,
			  let coordinator = delegate.currentCoordinator,
			  let operation = delegate.currentOperation else {
			return
		}
		
		// Calculate progress from gesture
		let translation = gestureRecognizer.translation(in: view).x
		let width = view.bounds.width
		let progress = min(max(translation / width, 0), 1)
		
		// Track gesture state for completion/cancellation detection
		let state = gestureRecognizer.state
		let velocity = gestureRecognizer.velocity(in: view).x
		
		print("📍 Native gesture - Progress: \(String(format: "%.2f", progress)), State: \(state.rawValue), Velocity: \(String(format: "%.0f", velocity))")
		
		// Call the alongside handler with our custom progress and gesture state
		alongsideHandler(operation, coordinator, progress, state)
		
		// Handle gesture ending states
		if state == .ended || state == .cancelled || state == .failed {
			// Predict if gesture will complete or cancel based on progress and velocity
			let willComplete = (velocity > 675) || (progress >= 0.2 && velocity > -200)
			print("📍 Gesture ending - Will complete: \(willComplete)")
		}
	}
	
	@objc private func setViewControllers_animateIfNeeded(_ viewControllers: [UIViewController], animated: Bool) {
		if let transitionDelegate = customDelegate {
			setViewControllers_animateIfNeeded(viewControllers, animated: transitionDelegate.transition.animation != nil)
		} else {
			setViewControllers_animateIfNeeded(viewControllers, animated: animated)
		}
	}

	@objc private func pushViewController_animateIfNeeded(_ viewController: UIViewController, animated: Bool) {
		if let transitionDelegate = customDelegate {
			pushViewController_animateIfNeeded(viewController, animated: transitionDelegate.transition.animation != nil)
		} else {
			pushViewController_animateIfNeeded(viewController, animated: animated)
		}
	}

	@objc private func popViewController_animateIfNeeded(animated: Bool) -> UIViewController? {
		if let transitionDelegate = customDelegate {
			popViewController_animateIfNeeded(animated: transitionDelegate.transition.animation != nil)
		} else {
			popViewController_animateIfNeeded(animated: animated)
		}
	}

	@objc private func popToViewController_animateIfNeeded(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
		if let transitionDelegate = customDelegate {
			popToViewController_animateIfNeeded(viewController, animated: transitionDelegate.transition.animation != nil)
		} else {
			popToViewController_animateIfNeeded(viewController, animated: animated)
		}
	}

	@objc private func popToRootViewController_animateIfNeeded(animated: Bool) -> UIViewController? {
		if let transitionDelegate = customDelegate {
			popToRootViewController_animateIfNeeded(animated: transitionDelegate.transition.animation != nil)
		} else {
			popToRootViewController_animateIfNeeded(animated: animated)
		}
	}
}

@available(tvOS, unavailable)
@available(visionOS, unavailable)
extension UINavigationController {
	var defaultEdgePanRecognizer: UIScreenEdgePanGestureRecognizer! {
		interactivePopGestureRecognizer as? UIScreenEdgePanGestureRecognizer
	}

	var defaultPanRecognizer: UIPanGestureRecognizer! {
		get { self[] }
		set { self[] = newValue }
	}

	var edgePanRecognizer: UIScreenEdgePanGestureRecognizer! {
		get { self[] }
		set { self[] = newValue }
	}

	var panRecognizer: UIPanGestureRecognizer! {
		get { self[] }
		set { self[] = newValue }
	}
}

extension UIGestureRecognizer {
	func hasTarget(_ target: Any, action: Selector) -> Bool {
		// Check if this gesture recognizer already has the specified target/action
		if let targets = self.value(forKey: "targets") as? [Any] {
			for targetActionPair in targets {
				if let targetInfo = targetActionPair as? NSObject,
				   let storedTarget = targetInfo.value(forKey: "target") as? NSObject,
				   storedTarget === (target as AnyObject) {
					return true
				}
			}
		}
		return false
	}
}

@available(tvOS, unavailable)
extension UIGestureRecognizer {
	var strongDelegate: (any UIGestureRecognizerDelegate)? {
		get { self[] }
		set {
			self[] = newValue
			delegate = newValue
		}
	}

	var targets: Any? {
		get {
			value(forKey: #function)
		}
		set {
			if let newValue {
				setValue(newValue, forKey: #function)
			} else {
				setValue(NSMutableArray(), forKey: #function)
			}
		}
	}
}

@available(tvOS, unavailable)
final class NavigationGestureRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
	private unowned let navigationController: UINavigationController

	init(controller: UINavigationController) {
		self.navigationController = controller
	}

	// TODO: swizzle instead
	func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		let isNotOnRoot = navigationController.viewControllers.count > 1
		let noModalIsPresented = navigationController.presentedViewController == nil // TODO: check if this check is still needed after iOS 17 public release
		return isNotOnRoot && noModalIsPresented
	}
}
