
import Foundation

public class SwiftPoller<T: Codable> {
    public typealias PollerClosure = () async -> T?
    public typealias PollerResult = Result<T, PollerError>
    private var poller: PollerClosure
    private var timeOut: TimeInterval
    private var frequency: TimeInterval
    private var isPolling: Bool = false
    private var startTime: Date?

    public init(frequency: TimeInterval = 5.0, timeOut: TimeInterval = 180.0, poller: @escaping PollerClosure) {
        self.poller = poller
        self.frequency = frequency
        self.timeOut = timeOut
    }

    public func stopPolling() {
        isPolling = false
    }

    public func startPolling() async -> PollerResult {
        isPolling = true
        startTime = Date()

        while isPolling {
            if let startTime = startTime, Date().timeIntervalSince(startTime) > timeOut {
                isPolling = false
                return .failure(.timeOut)
            }

            guard let item = await poller() else {
                try? await Task.sleep(nanoseconds: timeToNanoSecs(frequency))
                continue
            }

            return .success(item)
        }

        return .failure(.stopped)
    }
}

public extension SwiftPoller {
    internal func timeToNanoSecs(_ time: TimeInterval) -> UInt64 {
        UInt64(time * 1_000_000_000)
    }

    var elapsedTime: TimeInterval {
        guard let startTime = startTime else {
            return 0
        }
        return Date().timeIntervalSince(startTime)
    }
}
