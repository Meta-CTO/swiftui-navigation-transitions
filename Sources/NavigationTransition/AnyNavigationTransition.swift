public import Animation
public import UIKit

public struct AnyNavigationTransition {
	package typealias TransientHandler = (
		AnimatorTransientView,
		AnimatorTransientView,
		NavigationTransitionOperation,
		UIView
	) -> Void

	package typealias PrimitiveHandler = (
		any Animator,
		NavigationTransitionOperation,
		any UIViewControllerContextTransitioning
	) -> Void

	public typealias AlongsideHandler = (
		NavigationTransitionOperation,
		any UIViewControllerTransitionCoordinatorContext,
		CGFloat?, // Optional custom progress override
		UIGestureRecognizer.State? // Optional gesture state
	) -> Void

	package enum Handler {
		case transient(TransientHandler)
		case primitive(PrimitiveHandler)
	}

	package let isDefault: Bool
	package let handler: Handler
	package var alongsideHandler: AlongsideHandler?
	package var animation: Animation? = .default

	public init(_ transition: some NavigationTransitionProtocol) {
		self.isDefault = false
		self.handler = .transient(transition.transition(from:to:for:in:))
		self.alongsideHandler = nil
	}

	public init(_ transition: some PrimitiveNavigationTransition) {
		self.isDefault = transition is Default
		self.handler = .primitive(transition.transition(with:for:in:))
		self.alongsideHandler = nil
	}
}

public typealias _Animation = Animation

extension AnyNavigationTransition {
	/// Typealias for `Animation`.
	public typealias Animation = _Animation

	/// Attaches an animation to this transition.
	public func animation(_ animation: Animation?) -> Self {
		var copy = self
		copy.animation = animation
		return copy
	}

	/// Adds alongside animations that run with default transitions using iOS's transition coordinator.
	/// Only works with `.default` transitions.
	public func alongsideDefault(_ handler: @escaping AlongsideHandler) -> Self {
		var copy = self
		copy.alongsideHandler = handler
		return copy
	}
}

extension UIViewController {
    private enum HideTabBarKey {
        @MainActor static var hidesTabBarKey: UInt8 = 10
    }
    
    public var hidesTabBarWhenPushed: Bool {
        get {
            return objc_getAssociatedObject(self, &HideTabBarKey.hidesTabBarKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &HideTabBarKey.hidesTabBarKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

extension AnyNavigationTransition {
    @MainActor
    public static func withTabBarAnimation() -> AnyNavigationTransition {
        return .default.alongsideDefault { operation, context, customProgress, gestureState in
            let fromVC = context.viewController(forKey: .from)
            let toVC = context.viewController(forKey: .to)
            guard let tabBar = fromVC?.tabBarController?.tabBar ?? toVC?.tabBarController?.tabBar else { return }
            
            let screenWidth = UIScreen.main.bounds.width
            let shouldHideTabBar = toVC?.hidesTabBarWhenPushed ?? false
            
            switch operation {
            case .push:
                if shouldHideTabBar {
                    tabBar.frame.origin.x = -screenWidth
                } else if !(fromVC?.hidesTabBarWhenPushed ?? false) {
                    tabBar.frame.origin.x = 0
                }
                
            case .pop:
                if context.isCancelled {
                    tabBar.isHidden = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + context.transitionDuration) {
                        tabBar.frame.origin.x = -screenWidth
                        tabBar.isHidden = false
                    }
                } else {
                    let progress = customProgress ?? context.percentComplete
                    if !shouldHideTabBar {
                        if progress == 0 {
                            tabBar.frame.origin.x = 0
                            tabBar.isHidden = false
                        }
                    }
                }
                
            @unknown default:
                break
            }
        }
    }
}
