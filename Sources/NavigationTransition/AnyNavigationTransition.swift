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
