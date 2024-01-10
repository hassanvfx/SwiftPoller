//
//  File.swift
//
//
//  Created by Eon Fluxor on 1/9/24.
//

public extension SwiftPoller {
    enum PollerError: Error {
        case none
        case stopped
        case timeOut
        case undetermined
    }
}
