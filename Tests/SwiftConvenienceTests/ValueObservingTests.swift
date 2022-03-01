import SwiftConvenience

import Combine
import XCTest

private struct ValueWrapper<T>: ValueObserving {
    var value: T {
        willSet { subscriptions.notify(newValue) }
    }
    private let subscriptions = SubscriptionMap<T>()
    func subscribeReceiveValue(receiveValue: @escaping (T) -> Void) -> SubscriptionToken {
        subscriptions.subscribe(notifyImmediately: value, action: receiveValue)
    }
}

class ValueObservingTests: XCTestCase {
    private var cancellables: [AnyCancellable] = []
    
    func test_receiveValue() {
        var wrapper = ValueWrapper(value: 10)
        XCTAssertEqual(wrapper.value, 10)
        
        var receivedValue: Int?
        wrapper.subscribeReceiveValue {
            receivedValue = $0
        }.store(in: &cancellables)
        
        XCTAssertEqual(receivedValue, 10)
        
        wrapper.value = 20
        XCTAssertEqual(receivedValue, 20)
        
        wrapper.value = 30
        XCTAssertEqual(receivedValue, 30)
    }
    
    func test_receiveChange() {
        var wrapper = ValueWrapper(value: 10)
        XCTAssertEqual(wrapper.value, 10)
        
        var receivedChange: Change<Int>?
        wrapper.subscribeReceiveChange {
            receivedChange = $0
        }.store(in: &cancellables)
        
        XCTAssertEqual(receivedChange, nil)
        
        wrapper.value = 20
        XCTAssertEqual(receivedChange, .unchecked(old: 10, new: 20))
        
        wrapper.value = 30
        XCTAssertEqual(receivedChange, .unchecked(old: 20, new: 30))
    }
}
