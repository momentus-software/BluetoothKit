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
    The delegate of a remote peripheral receives callbacks when asynchronous events occur.
*/
public protocol BKRemotePeripheralDelegate: class {
    /**
        Called when the remote peripheral updated its name.
        - parameter remotePeripheral: The remote peripheral that updated its name.
        - parameter name: The new name.
    */
    func remotePeripheral(remotePeripheral: BKRemotePeripheral, didUpdateName name: String)
    /**
        Called when the remote peripheral sent data.
        - parameter remotePeripheral: The remote peripheral that sent the data.
        - parameter data: The data it sent.
    */
    func remotePeripheral(remotePeripheral: BKRemotePeripheral, didReceiveArbitraryData data: NSData)
    
    func remotePeripheral(remotePeripheral: BKRemotePeripheral, willSendData data: NSData)
    
    func remotePeripheral(remotePeripheral: BKRemotePeripheral, didReceiveError error: NSError?)
}

public func ==(lhs: BKRemotePeripheral, rhs: BKRemotePeripheral) -> Bool {
    return lhs.identifier.UUIDString == rhs.identifier.UUIDString
}

/**
    Class to represent a remote peripheral that can be connected to by BKCentral objects.
*/
public class BKRemotePeripheral: BKCBPeripheralDelegate, Equatable {
    
    // MARK: Enums
    
    /**
        Possible states for BKRemotePeripheral objects.
        - Shallow: The peripheral was initialized only with an identifier (used when one wants to connect to a peripheral for which the identifier is known in advance).
        - Disconnected: The peripheral is disconnected.
        - Connecting: The peripheral is currently connecting.
        - Connected: The peripheral is already connected.
        - Disconnecting: The peripheral is currently disconnecting.
    */
    public enum State {
        case Shallow, Disconnected, Connecting, Connected, Disconnecting
    }
    
    private var sendDataTasks = [BKCentralSendDataTask]()
    
    public enum Error: ErrorType {
        case InterruptedByUnavailability(cause: BKUnavailabilityCause)
        case CharacteristicNotFound
        case InternalError(underlyingError: ErrorType?)
    }
    
    public typealias SendDataCompletionHandler = ((data: NSData, characteristic: CBCharacteristic?, error: Error?) -> Void)
    
    // MARK: Properties
    
    /// The current state of the remote peripheral, either shallow or derived from an underlying CBPeripheral object.
    public var state: State {
        if peripheral == nil {
            return .Shallow
        }
        #if os(iOS)
        switch peripheral!.state {
            case .Disconnected: return .Disconnected
            case .Connecting: return .Connecting
            case .Connected: return .Connected
            case .Disconnecting: return .Disconnecting
        }
        #else
        switch peripheral!.state {
            case .Disconnected: return .Disconnected
            case .Connecting: return .Connecting
            case .Connected: return .Connected
        }
        #endif
    }
    
    /// The name of the remote peripheral, derived from an underlying CBPeripheral object.
    public var name: String? {
        return peripheral?.name
    }
    
    /// The remote peripheral's delegate.
    public weak var delegate: BKRemotePeripheralDelegate?
    
    /// The unique identifier of the remote peripheral object.
    public let identifier: NSUUID
    
    public var peripheral: CBPeripheral?
    internal var configuration: BKConfiguration?
    
    private var data: NSMutableData?
    private var peripheralDelegate: BKCBPeripheralDelegateProxy!
    
    
    private var dataLength: Int?
    
    // [characteristic, true] = idle
    private var centralCharacteristics: [CBCharacteristic: Bool]
    
    // MARK: Initialization
    
    public init(identifier: NSUUID, peripheral: CBPeripheral?) {
        self.centralCharacteristics = Dictionary()
        self.identifier = identifier
        self.peripheralDelegate = BKCBPeripheralDelegateProxy(delegate: self)
        self.peripheral = peripheral
    }
    
    // MARK: Internal Functions
    
    internal func prepareForConnection() {
        peripheral?.delegate = peripheralDelegate
    }
    
    internal func discoverServices() {
        if peripheral?.services != nil {
            peripheral(peripheral!, didDiscoverServices: nil)
            return
        }
        peripheral?.discoverServices(configuration!.serviceUUIDs)
    }
    
    internal func unsubscribe() {
        guard peripheral?.services != nil else {
            return
        }
        for service in peripheral!.services! {
            guard service.characteristics != nil else {
                continue
            }
            for characteristic in service.characteristics! {
                peripheral?.setNotifyValue(false, forCharacteristic: characteristic)
            }
        }
    }
    
    public func sendData(data: NSData, completionHandler: SendDataCompletionHandler) {
        delegate?.remotePeripheral(self, willSendData: data)
        
        
        guard self.centralCharacteristics.count > 0 else {
            completionHandler(data: data, characteristic:nil, error: Error.CharacteristicNotFound)
            return
        }
        
        var maximumPayloadLength: Int = 512
        
        if #available(iOS 9.0, *) {
            maximumPayloadLength = (self.peripheral?.maximumWriteValueLengthForType(CBCharacteristicWriteType.WithResponse))!
        } else {
            // TODO: fall back for prev version
        }
        
        print("Negotiated MTU \(maximumPayloadLength)")
        let sendDataTask = BKCentralSendDataTask(data: data, maximumPayloadLength: maximumPayloadLength, completionHandler: completionHandler)
        
        sendDataTasks.append(sendDataTask)
        if sendDataTasks.count >= 1 {
            processSendDataTasks()
        }
    }
    
    internal func allKeysForValue<K, V : Equatable>(dict: [K : V], val: V) -> [K] {
        return dict.filter{ $0.1 == val }.map{ $0.0 }
    }
    
    private func processSendDataTasks() {
        guard sendDataTasks.count > 0 else {
            return
        }
        
        let nextTask = sendDataTasks.first!
        
        let idleCharacteristics = allKeysForValue(self.centralCharacteristics, val: true)
        
        if (idleCharacteristics.count > 0) {
            
            let idleCharacteristic = idleCharacteristics.first
            
            if nextTask.sentAllData {
                
                self.centralCharacteristics[idleCharacteristic!] = false
                self.peripheral?.writeValue((self.configuration?.endOfDataMark)!, forCharacteristic:idleCharacteristic!, type: CBCharacteristicWriteType.WithResponse)
                sendDataTasks.removeAtIndex(sendDataTasks.indexOf(nextTask)!)
                nextTask.completionHandler?(data: nextTask.data, characteristic: idleCharacteristic!, error: nil)
                processSendDataTasks()
                return
            }
            
            let nextPayload = nextTask.nextPayload
            
//            NSLog("sending \(nextTask.offset) : \(idleCharacteristic?.UUID)")
            self.centralCharacteristics[idleCharacteristic!] = false
            self.peripheral?.writeValue(nextPayload, forCharacteristic:idleCharacteristic!, type: CBCharacteristicWriteType.WithResponse)
            nextTask.offset += nextPayload.length
            
            if idleCharacteristics.count > 1 {
                processSendDataTasks()
            }
            
        } else {
            return
        }
    }

    
    // MARK: Private Functions
    
    private func handleReceivedData(receivedData: NSData) {
        if receivedData.isEqualToData(configuration!.endOfDataMark) {
            if let finalData = data {
                delegate?.remotePeripheral(self, didReceiveArbitraryData: finalData)
            }
            data = nil
            return
        }
        if let existingData = data {
            existingData.appendData(receivedData)
            return
        }
        data = NSMutableData(data: receivedData)
    }
    
    // MARK: BKCBPeripheralDelegate
    
    internal func peripheralDidUpdateName(peripheral: CBPeripheral) {
        delegate?.remotePeripheral(self, didUpdateName: name!)
    }
    
    internal func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        print("didDiscoverServices", peripheral.services)
        if let services = peripheral.services {
            for service in services {
                if service.characteristics != nil {
                    self.peripheral(peripheral, didDiscoverCharacteristicsForService: service, error: nil)
                } else  {
                    peripheral.discoverCharacteristics(configuration!.characteristicUUIDsForServiceUUID(service.UUID), forService: service)
                }
            }
        }
    }
    
    internal func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if service.UUID == configuration!.dataServiceUUID {
            if let dataCharacteristics = service.characteristics?.filter({ configuration!.centralServiceCharacteristicUUIDs.contains($0.UUID) || configuration!.peripheralServiceCharacteristicUUID == $0.UUID}) {
                
                for characteristic: CBCharacteristic in dataCharacteristics {
                    
                    if configuration!.centralServiceCharacteristicUUIDs.contains(characteristic.UUID) {
                        self.centralCharacteristics[characteristic] = true
                    }
                    peripheral.setNotifyValue(true, forCharacteristic: characteristic)
                }
            }
        }
        else if service.UUID == configuration!.ANCSNotificationServiceUUID {
            for characteristic: CBCharacteristic in service.characteristics! {
                peripheral.setNotifyValue(true, forCharacteristic: characteristic)
            }
        }
        // TODO: Consider what to do with characteristics from additional services.
    }
    
    internal func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        self.centralCharacteristics[characteristic] = true
        if sendDataTasks.count > 0 {
            processSendDataTasks()
            if error != nil {
                delegate?.remotePeripheral(self, didReceiveError: error)
            }
        }
        else {

        }
    }
    
    internal func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if configuration!.peripheralServiceCharacteristicUUID == characteristic.UUID {
            handleReceivedData(characteristic.value!)
        }
        else {
            print("didUpdateValueForCharacteristic::Characteristic not handled")
        }
        // TODO: Consider what to do with new values for characteristics from additional services.
    }
    
}
