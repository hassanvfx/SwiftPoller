//
//  DemoAppTests.swift
//  DemoAppTests
//
//  Created by hassan uriostegui on 8/30/22.
//

@testable import DemoApp
import XCTest
import SwiftPoller

struct MockResult: Codable,Equatable {
    var data: String
}


class DemoAppTests: XCTestCase {
    func testPollerRespondsAfterThreeCalls() async {
        // Arrange
        var pollCount = 0
        let expectedResult = MockResult(data: "Success")
        
        
        let poller = SwiftPoller<MockResult>{
            pollCount += 1
            return pollCount == 3 ? expectedResult : nil
        }
        
        
        // Act
        let result = await poller.startPolling()
        
        // Assert
        switch result {
        case .success(let data):
            XCTAssertEqual(data, expectedResult, "Poller did not return expected result after three calls")
        default:
            XCTFail("Poller did not complete successfully")
        }
    }
    
    func testPollerTimeOut() async {
        // Arrange
        var pollCount = 0
        let expectedResult = MockResult(data: "Success")
        
        
        let poller = SwiftPoller<MockResult>(frequency:1,timeOut: 3){
            pollCount += 1
            return pollCount == 40 ? expectedResult : nil
        }
        
        
        // Act
        let result = await poller.startPolling()
        
        // Assert
        switch result {
        case .success:
            XCTFail("Poller did call unexpected result")
        default:
            XCTAssertTrue(true,"Poller did not complete as expected")
        }
    }
}
class SwiftPollerQueueTests: XCTestCase {

    func testConcurrency() async {
        let expectation = XCTestExpectation(description: "Concurrent processing of pollers")
        expectation.expectedFulfillmentCount = 3 // Number of pollers

        // Mock Poller
        func createPoller(completion: @escaping () -> Void) -> SwiftPoller<MockResult> {
            return SwiftPoller<MockResult>(frequency:1,timeOut:10)  {
                completion()
                return MockResult(data: "Success") // Replace with actual result
            }
        }

        // Create SwiftPollerQueue with multiple workers
        let queue = SwiftPollerQueue<MockResult>(workers: 3){ item in
            
        }

        // Add pollers
        for _ in 1...3 {
            await queue.add(poller: createPoller {
                expectation.fulfill()
            })
        }

        // Start queue
        Task {
            await queue.start()
        }

        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    func testCompletion() async {
        let expectation = XCTestExpectation(description: "Completion of all pollers")

        var processedPollers = 0
        let totalPollers = 3

        // Mock Poller
        func createPoller() -> SwiftPoller<MockResult>{
            return SwiftPoller<MockResult>(frequency:1,timeOut:10)  {
                processedPollers += 1
                if processedPollers == totalPollers {
                    expectation.fulfill()
                }
                return MockResult(data: "Success") // Replace with actual result
            }
        }

        // Create SwiftPollerQueue
        let queue = SwiftPollerQueue<MockResult>(workers: 1){ item in
            
        }

        // Add pollers
        for _ in 1...totalPollers {
            await queue.add(poller: createPoller())
        }

        // Start queue
        Task {
            await queue.start()
        }

        await fulfillment(of: [expectation], timeout: 10.0)
    }
}

class SwiftPollerQueueFIFOTests: XCTestCase {

    func testFIFOOrder() async {
        let expectation = XCTestExpectation(description: "FIFO processing of pollers")
        expectation.expectedFulfillmentCount = 1

        var results = [MockResult?]()
        let pollerOrder = [2, 1, 3] // Order in which pollers are expected to respond

        // Create a poller with a specified delay
        func createPoller(order: Int) -> SwiftPoller<MockResult> {
            return SwiftPoller<MockResult>(frequency: 1, timeOut: 10) {
                return MockResult(data: "Result \(order)")
            }
        }

        // Create SwiftPollerQueue
        let queue = SwiftPollerQueue<MockResult>(workers: 1) { item in
            results.append(item.result)
            if results.count == pollerOrder.count {
                expectation.fulfill()
            }
        }

        // Add pollers in the specified order
        for order in pollerOrder {
            await queue.add(poller: createPoller(order: order))
        }

        // Start queue
        Task {
            await queue.start()
        }

        await fulfillment(of: [expectation], timeout: 10.0)

        // Assert FIFO order
        let expectedResults = pollerOrder.map { MockResult(data: "Result \($0)") }
        XCTAssertEqual(results, expectedResults, "Pollers did not complete in FIFO order")
    }
    
    
    func testFIFOOrderMultipleWorkers() async {
        let expectation = XCTestExpectation(description: "FIFO processing of pollers")
        expectation.expectedFulfillmentCount = 1

        var results = [MockResult?]()
        let pollerOrder = [2, 1, 3, 9, 10, 11, 12] // Order in which pollers are expected to respond

        // Create a poller with a specified delay
        func createPoller(order: Int) -> SwiftPoller<MockResult> {
            return SwiftPoller<MockResult>(frequency: 1, timeOut: 10) {
                return MockResult(data: "Result \(order)")
            }
        }

        // Create SwiftPollerQueue
        let queue = SwiftPollerQueue<MockResult>(workers: 3) { item in
            results.append(item.result)
            if results.count == pollerOrder.count {
                expectation.fulfill()
            }
        }

        // Add pollers in the specified order
        for order in pollerOrder {
            await queue.add(id:"\(order)",poller: createPoller(order: order))
        }

        // Start queue
        Task {
            await queue.start()
        }

        await fulfillment(of: [expectation], timeout: 10.0)

        // Assert FIFO order
        let expectedResults = pollerOrder.map { MockResult(data: "Result \($0)") }
        XCTAssertEqual(results, expectedResults, "Pollers did not complete in FIFO order")
    }
}
