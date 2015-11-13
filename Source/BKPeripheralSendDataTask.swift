//
//  BKPeripheralSendDataTask.swift
//  Pods
//
//  Created by Dillon Yang on 2015-11-05.
//
//

import Foundation

internal func ==(lhs: BKPeripheralSendDataTask, rhs: BKPeripheralSendDataTask) -> Bool {
    return lhs.destination == rhs.destination && lhs.data.isEqualToData(rhs.data)
}


internal class BKPeripheralSendDataTask: BKSendDataTask, Equatable {
    
    internal let destination: BKRemoteCentral
    internal var completionHandler: ((data: NSData, remoteCentral: BKRemoteCentral, error: BKPeripheral.Error?) -> Void)?
    
    // MARK: Initialization
    
    internal init(data: NSData, destination: BKRemoteCentral, maximumPayloadLength: Int, completionHandler: ((data: NSData, remoteCentral: BKRemoteCentral, error: BKPeripheral.Error?) -> Void)?) {
        self.destination = destination
        self.completionHandler = completionHandler
        super.init(data: data, maximumPayloadLength: maximumPayloadLength)
    }
}