import Foundation

public actor SwiftPollerQueue<T: Codable> {
    private class PollerWrapper<W: Codable> {
        var id:String?
        let poller: SwiftPoller<W>
        let timestamp: Date
        
        init(id:String? = nil, poller: SwiftPoller<W>, timestamp: Date) {
            self.id = id
            self.poller = poller
            self.timestamp = timestamp
        }
    }
    
    public class ResolutionEntry<R> {
        public var id:String?
        public let result: R?
        public let timestamp: Date
        
        public init(id:String? = nil, result: R?, timestamp: Date) {
            self.id=id
            self.result = result
            self.timestamp = timestamp
        }
    }
    
    private var pollers: [PollerWrapper<T>] = []
    private var resolutionBuffer: [ResolutionEntry<T>] = []
    private var isPolling: Bool = false
    private var interval: TimeInterval
    private var responseInterval: TimeInterval
    private let workers: Int
    public var responseClosure: ((ResolutionEntry<T>) -> Void)?
    
    public init(interval: TimeInterval = 1.0, responseInterval: TimeInterval? = nil, workers: Int = 1, callback:((ResolutionEntry<T>)-> Void)? = nil) {
        self.interval = interval
        self.workers = max(workers, 1)
        self.responseInterval = responseInterval ?? interval * 2
        self.responseClosure = callback
    }
    
    public func add(id:String? = nil, poller: SwiftPoller<T>) {
        self.pollers.append(PollerWrapper(id:id, poller: poller, timestamp: Date()))
    }
    
    
    public func start() async {
        self.isPolling = true
        
        if let responseClosure {
            Task {
                await self.runResolutionWorker(callback: responseClosure)
            }
        }
        
        for _ in 0..<workers {
            Task {
                await self.runPolling()
            }
        }
    }
    
    private func runPolling() async {
        while isPolling {
            var currentWrapper: PollerWrapper<T>?
            
            currentWrapper = self.pollers.isEmpty ? nil : self.pollers.removeFirst()
            
            if let wrapper = currentWrapper {
                let poller = wrapper.poller 
                let result = await poller.startPolling()
                switch result {
                case .success(let data):
                    //                    resolutionQueue.async {
                    self.resolutionBuffer.append(ResolutionEntry(id:wrapper.id, result: data, timestamp: wrapper.timestamp))
                    //                    }
                case .failure:
                    self.resolutionBuffer.append(ResolutionEntry(result: nil, timestamp: wrapper.timestamp))
                    // Handle error
                }
            }
            
            // Sleep for the specified duration
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }
    
    private func runResolutionWorker(callback:(ResolutionEntry<T>) -> Void) async {
        while isPolling {
            self.resolutionBuffer.sort { $0.timestamp < $1.timestamp }
            while !self.resolutionBuffer.isEmpty {
                if let entry = self.resolutionBuffer.first {
                    callback(entry)
                    self.resolutionBuffer.removeFirst()
                }
            }
            try? await Task.sleep(nanoseconds: UInt64(responseInterval * 1_000_000_000))
        }
    }
    
    public func stop() {
        //        queue.async(flags: .barrier) {
        self.isPolling = false
        //        }
    }
    
    public func setSleepDuration(_ duration: TimeInterval) {
        //        queue.async(flags: .barrier) {
        self.interval = duration
        //        }
    }
}
