//  MIT License
//
//  Copyright (c) 2022 Alkenso (Vladimir Vashurkin)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation

// MARK: - Dictionary

extension Dictionary {
    /// Get the value in nested dictionary
    /// Specific cases:
    ///     - Nested Array:
    ///         - pass [1] to follow the 1-st item in the nested array
    ///         - pass [Int.max] to follow the last item in the nested array
    public subscript(keyPath keyPath: [AnyHashable]) -> Any? {
        var lastItem: Any? = self
        for keyPathComponent in keyPath {
            switch lastItem {
            case let collection as [AnyHashable: Any]:
                lastItem = collection[keyPathComponent]
            case let collection as [AnyHashable]:
                if let arrayIndexkey = keyPathComponent as? [Int], arrayIndexkey.count == 1 {
                    let idx = arrayIndexkey[0]
                    lastItem = idx != .max ? collection[safe: idx] : collection.last
                } else {
                    lastItem = nil
                }
            default:
                return nil
            }
        }
        
        return lastItem
    }
    
    /// Inserts value into nested dictionary at key path
    /// If nested dictionary(one or multiple) does not exist, they are created as [AnyHashable: Any]
    /// If value at any nested level according to key path has unappropriate type, the error is thrown
    public mutating func insert(value: Any?, at keyPath: [AnyHashable]) throws {
        guard let nextKey = keyPath.first as? Key else { return }
        
        let nestedKeyPath = Array(keyPath.dropFirst())
        guard !nestedKeyPath.isEmpty else {
            let typedValue = try (value as? Value).get(ifNil: CommonError.cast(
                value,
                to: Value.self,
                description: "Failed to insert value of unappropriate type"
            ))
            self[nextKey] = typedValue
            return
        }
        
        var nested = try nestedDict(for: nextKey)
        try nested.insert(value: value, at: nestedKeyPath)
        self[nextKey] = try (nested as? Value).get(ifNil: CommonError.cast(
            value,
            to: Value.self,
            description: "Failed to insert value of unappropriate type as nested dictionary"
        ))
    }
    
    private func nestedDict(for key: Key) throws -> [AnyHashable: Any] {
        guard let value = self[key] else { return [AnyHashable: Any]() }
        let nestedDict = try (value as? [AnyHashable: Any])
            .get(ifNil: CommonError.cast(
                value,
                to: [AnyHashable: Any].self,
                description: "Trying to insert value to nested dictionary but unexpected type found"
            ))
        return nestedDict
    }
}

extension Dictionary {
    /// Get value in nested dictionary using dot-separated key path.
    /// Keys in dictionary at keyPath componenets must be of String type
    /// Specific cases:
    ///     - Nested Array:
    ///         - pass [1] to follow the 1-st item in the nested array
    ///         - pass [*] to follow the last item in the nested array
    public subscript(dotPath dotPath: String) -> Any? {
        guard !dotPath.isEmpty else { return self }
        
        let components: [AnyHashable] = dotPath.components(separatedBy: ".").map {
            if $0 == "[*]" {
                return [Int.max]
            } else if $0.hasPrefix("[") && $0.hasSuffix("]"),
                      let idx = Int($0.dropFirst().dropLast()) {
                return [idx]
            } else {
                return $0
            }
        }
        return self[keyPath: components]
    }

    /// Inserts value in nested dictionary using dot-separated key path
    public mutating func insert(value: Any?, at dotPath: String) throws {
        try insert(value: value, at: dotPath.components(separatedBy: "."))
    }
}

extension Dictionary {
    public func `get`<T>(_ key: Key, transform: (Value) -> T?) throws -> T {
        guard let value = self[key] else {
            throw CommonError.notFound(what: "\(key)", where: "\(self)")
        }
        guard let transformedValue = transform(value) else {
            throw CommonError.cast(
                value,
                to: T.self,
                description: "Invalid value type for key '\(key)' in dict \(String(describing: self))"
            )
        }
        return transformedValue
    }
    
    public func `get`<T>(_ key: Key, as type: T.Type) throws -> T {
        try get(key) { $0 as? T }
    }
}

// MARK: - Array

extension Array {
    public mutating func mutateElements(mutate: (inout Element) throws -> Void) rethrows {
        self = try mutatingMap(mutate: mutate)
    }
    
    public func appending(_ newElement: Element) -> Self {
        var appended = self
        appended.append(newElement)
        return appended
    }
}

extension Array {
    public subscript(safe index: Index) -> Element? {
        index < count ? self[index] : nil
    }
}

// MARK: - Collection

extension Collection {
    public func mutatingMap(mutate: (inout Element) throws -> Void) rethrows -> [Element] {
        try map {
            var mutated = $0
            try mutate(&mutated)
            return mutated
        }
    }
}
