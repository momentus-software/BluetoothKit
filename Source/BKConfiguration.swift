//
//  BluetoothKit
//
//  Copyright (c) 2015 Rasmus Taulborg Hummelmose - https://github.com/rasmusth
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import CoreBluetooth

/**
    Class that represents a configuration used when starting a BKCentral object.
*/
public class BKConfiguration {
    
    // MARK: Properties
    
    /// The UUID for the service used to send data. This should be unique to your applications.
    public let dataServiceUUID: CBUUID
    
    /// The UUID for the characteristic used to send data. This should be unique to your application.
    public var peripheralServiceCharacteristicUUID: CBUUID
    public var centralServiceCharacteristicUUIDs: [CBUUID]
    
    // ANCS Notifications
    public let ANCSNotificationServiceUUID: CBUUID = CBUUID(string: "7905F431-B5CE-4E99-A40F-4B1E122D00D0")
    public let ANCSNotificationSourceUUID: CBUUID = CBUUID(string: "9FBF120D-6301-42D9-8C58-25E699A21DBD")
    public let ANCSControlPointUUID: CBUUID = CBUUID(string: "69D1D8F3-45E1-49A8-9821-9BBDFDAAD9D9")
    public let ANCSDataSourceUUID: CBUUID = CBUUID(string: "22EAC6E9-24D6-4BB5-BE44-B36ACE7C7BFB")
    
    
    /// Data used to indicate that no more data is coming when communicating.
    public var endOfDataMark: NSData
    
    /// Data used to indicate that a transfer was cancellen when communicating.
    public var dataCancelledMark: NSData
    
    internal var serviceUUIDs: [CBUUID] {
        let serviceUUIDs = [ dataServiceUUID, ANCSNotificationServiceUUID ]
        return serviceUUIDs
    }
    
    // MARK: Initialization

    public init(dataServiceUUID: NSUUID, centralServiceCharacteristicUUIDs: [NSUUID], peripheralServiceCharacteristicUUID: NSUUID) {
        self.dataServiceUUID = CBUUID(NSUUID: dataServiceUUID)
        self.peripheralServiceCharacteristicUUID = CBUUID(NSUUID: peripheralServiceCharacteristicUUID)
        self.centralServiceCharacteristicUUIDs = []
        for nsuuid: NSUUID in centralServiceCharacteristicUUIDs {
            self.centralServiceCharacteristicUUIDs.append(CBUUID(NSUUID: nsuuid))
        }

        endOfDataMark = "EOD".dataUsingEncoding(NSUTF8StringEncoding)!
        dataCancelledMark = "COD".dataUsingEncoding(NSUTF8StringEncoding)!
    }
    
    // MARK Functions
    
    internal func characteristicUUIDsForServiceUUID(serviceUUID: CBUUID) -> [CBUUID] {
        if serviceUUID == dataServiceUUID {
            var uuids: [CBUUID] = []
            uuids.append(peripheralServiceCharacteristicUUID)
            uuids.appendContentsOf(centralServiceCharacteristicUUIDs)
            return uuids
        }
        else if serviceUUID == ANCSNotificationServiceUUID {
            var uuids: [CBUUID] = []
            uuids.append(ANCSNotificationSourceUUID)
            uuids.append(ANCSControlPointUUID)
            uuids.append(ANCSDataSourceUUID)
        }
        return []
    }
    
}
