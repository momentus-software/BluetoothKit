//
//  BKCentralSendDataTask.swift
//  Pods
//
//  Created by Dillon Yang on 2015-11-05.
//
//

import Foundation
import CoreBluetooth

internal func ==(lhs: BKCentralSendDataTask, rhs: BKCentralSendDataTask) -> Bool {
    return lhs.data.isEqualToData(rhs.data)
}


internal class BKCentralSendDataTask: BKSendDataTask, Equatable {
    
    internal var completionHandler: ((data: NSData, characteristic: CBCharacteristic, error: BKRemotePeripheral.Error?) -> Void)?
    
    // MARK: Initialization
    
    internal init(data: NSData, maximumPayloadLength: Int, completionHandler: ((data: NSData, characteristic: CBCharacteristic, error: BKRemotePeripheral.Error?) -> Void)?) {
        self.completionHandler = completionHandler
        super.init(data: data, maximumPayloadLength: maximumPayloadLength)
    }
}