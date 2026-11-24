import Foundation

/// Lifecycle status reported by an optional cloud add-on (sync, MCP, calendar bridges…).
public enum CloudExtensionStatus: Equatable, Sendable {
    case disabled
    case idle
    case syncing
    case error(String)
}

/// Open-Core extension point for optional, privately distributed cloud add-ons.
///
/// The open-source app is 100% local-first and never requires an implementation of this
/// protocol. A managed add-on can conform to it and be injected into `MyBetterLifeRootView`
/// without the core app knowing anything about accounts, servers or credentials.
@MainActor
public protocol CloudExtensionProvider: AnyObject {
    /// Whether the add-on is active for the current user.
    var isEnabled: Bool { get }
    /// Current add-on status, suitable for lightweight UI indicators.
    var status: CloudExtensionStatus { get }
    /// Called once when the main window appears so the add-on can observe local mutations.
    func attach(to store: PlannerStore)
}

/// Default provider used by the open-source build: does nothing and reports `.disabled`.
@MainActor
public final class NoOpCloudExtensionProvider: CloudExtensionProvider {
    public init() {}

    public var isEnabled: Bool { false }
    public var status: CloudExtensionStatus { .disabled }

    public func attach(to store: PlannerStore) {}
}
