//
//  AdvertisementTestCase.swift
//  BluesTests
//
//  Created by Michał Kałużny on 11/09/2017.
//  Copyright © 2017 NWTN Berlin. All rights reserved.
//

import Foundation
import XCTest
import CoreBluetooth
@testable import Blues

class AdvertisementTestCase: XCTestCase {
    
    let dictionary: [String: Any] = [
        CBAdvertisementDataLocalNameKey: "Test Device",
        CBAdvertisementDataManufacturerDataKey: Data(),
        CBAdvertisementDataServiceDataKey: [CBUUID(): Data()],
        CBAdvertisementDataServiceUUIDsKey: [],
        CBAdvertisementDataOverflowServiceUUIDsKey: [],
        CBAdvertisementDataSolicitedServiceUUIDsKey: [],
        CBAdvertisementDataTxPowerLevelKey: 100,
        CBAdvertisementDataIsConnectable: true
    ]
    
    //MARK: Service Data
    func testExistingServiceData() {
        var dictionary = self.dictionary
        let uuid = UUID()
        dictionary[CBAdvertisementDataServiceDataKey] = [
            CBUUID(nsuuid: uuid): Data(),
        ] as Dictionary<CBUUID, Data>
        
        let advertisement = Advertisement(dictionary: dictionary)
        
        XCTAssertEqual(advertisement.serviceData?.count, 1)
    }
    
    func testEmptyServiceData() {
        var dictionary = self.dictionary
        
        dictionary[CBAdvertisementDataServiceDataKey] = [:] as Dictionary<CBUUID, Data>
        
        let advertisement = Advertisement(dictionary: dictionary)
        
        XCTAssertEqual(advertisement.serviceData?.count, 0)
    }
    
    func testNonUUIDServiceData() {
        var dictionary = self.dictionary
        
        dictionary[CBAdvertisementDataServiceDataKey] = ["Test": "Test"] as Dictionary<String, String>
        
        let advertisement = Advertisement(dictionary: dictionary)
        
        XCTAssertEqual(advertisement.serviceData?.count, nil)
    }
    
    //MARK: Services
    func testServices() {
        let services = [\Advertisement.serviceUUIDs: CBAdvertisementDataServiceUUIDsKey,
                        \Advertisement.overflowServiceUUIDs: CBAdvertisementDataOverflowServiceUUIDsKey,
                        \Advertisement.solicitedServiceUUIDs: CBAdvertisementDataSolicitedServiceUUIDsKey]
        
        for (keyPath, key) in services {
            testExistingServices(keyPath: keyPath, key: key)
            testDuplicatedServices(keyPath: keyPath, key: key)
            testEmptyServices(keyPath: keyPath, key: key)
            testNonUUIDServices(keyPath: keyPath, key: key)
        }
    }
    
    func testExistingServices(keyPath: KeyPath<Advertisement, [Identifier]?>, key: String) {
        var dictionary = self.dictionary
        let uuid = UUID()
        dictionary[key] = [
            CBUUID(nsuuid: uuid),
        ] as Array<CBUUID>
        
        let advertisement = Advertisement(dictionary: dictionary)
        let value = advertisement[keyPath: keyPath]

        XCTAssertEqual(value?.count, 1)

        guard let coreUUID = value?.first else {
            return XCTFail()
        }
        
        XCTAssertEqual(coreUUID.uuid.uuidString, uuid.uuidString)
    }
    
    func testDuplicatedServices(keyPath: KeyPath<Advertisement, [Identifier]?>, key: String) {
        var dictionary = self.dictionary
        let uuid = UUID()
        
        dictionary[key] = [
            CBUUID(nsuuid: uuid),
            CBUUID(nsuuid: uuid),
        ] as Array<CBUUID>
        
        let advertisement = Advertisement(dictionary: dictionary)
        let value = advertisement[keyPath: keyPath]

        XCTAssertEqual(value?.count, 2)
    }
    
    func testEmptyServices(keyPath: KeyPath<Advertisement, [Identifier]?>, key: String) {
        var dictionary = self.dictionary
        
        dictionary[key] = [] as Array<CBUUID>
        
        let advertisement = Advertisement(dictionary: dictionary)
        let value = advertisement[keyPath: keyPath]

        XCTAssertEqual(value?.count, 0)
    }
    
    func testNonUUIDServices(keyPath: KeyPath<Advertisement, [Identifier]?>, key: String) {
        var dictionary = self.dictionary
        
        dictionary[key] = ["Test"] as Array<String>
        
        let advertisement = Advertisement(dictionary: dictionary)
        let value = advertisement[keyPath: keyPath]
        XCTAssertEqual(value?.count, nil)
    }
    
    //MARK: Data Representation
    func testDataRepresentation() {
        let advertisement = Advertisement(dictionary: dictionary)
        let data = advertisement.data
        guard let copy = Advertisement(data: data) else {
            return XCTFail()
        }
        
        XCTAssertEqual(advertisement.localName, copy.localName)
        XCTAssertEqual(advertisement.isConnectable, copy.isConnectable)
        XCTAssertEqual(advertisement.txPowerLevel, copy.txPowerLevel)
        XCTAssertEqual(advertisement.manufacturerData, copy.manufacturerData)
        XCTAssert(areOptionalsEqual(advertisement.serviceUUIDs, copy.serviceUUIDs))
        XCTAssert(areOptionalsEqual(advertisement.solicitedServiceUUIDs, copy.solicitedServiceUUIDs))
        XCTAssert(areOptionalsEqual(advertisement.overflowServiceUUIDs, copy.overflowServiceUUIDs))
        
        guard
            let leftServiceData = advertisement.serviceData,
            let rightServiceData = copy.serviceData
        else {
            return XCTFail()
        }
        
        for (left, right) in zip(leftServiceData, rightServiceData) {
            XCTAssertEqual(left.key.string, right.key.string)
            XCTAssertEqual(left.value, right.value)
        }
    }
    
    //MARK: Primitive Values
    func testPowerLevel() {
        testPrimitiveValue(keyPath: \Advertisement.txPowerLevel, key: CBAdvertisementDataTxPowerLevelKey, expectedValue: 100)
    }
    
    func testLocalName() {
        testPrimitiveValue(keyPath: \Advertisement.localName, key: CBAdvertisementDataLocalNameKey, expectedValue: "Local Name")
    }
    
    func testIsConnectable() {
        testPrimitiveValue(keyPath: \Advertisement.isConnectable, key: CBAdvertisementDataIsConnectable, expectedValue: false)
    }
    
    func testPrimitiveValue<T: Equatable>(keyPath: KeyPath<Advertisement, T?>, key: String, expectedValue: T) {
        testPrimitiveValueExpected(keyPath: keyPath, key: key, value: expectedValue)
        testPrimitiveValueNotExpected(keyPath: keyPath, key: key)
        testPrimitiveValueNil(keyPath: keyPath, key: key)
    }
    
    //MARK: Generic Helpers
    func testPrimitiveValueExpected<T: Equatable>(keyPath: KeyPath<Advertisement, T?>, key: String, value: T) {
        var dictionary = self.dictionary
        
        dictionary[key] = value
        
        let advertisement = Advertisement(dictionary: dictionary)
        let transformed = advertisement[keyPath: keyPath]
        
        XCTAssertEqual(transformed!, value)
    }
    
    func testPrimitiveValueNotExpected<T: Equatable>(keyPath: KeyPath<Advertisement, T?>, key: String) {
        var dictionary = self.dictionary

        dictionary[key] = []
        
        let advertisement = Advertisement(dictionary: dictionary)
        let transformed = advertisement[keyPath: keyPath]
        
        XCTAssertEqual(transformed, nil)
    }
    
    func testPrimitiveValueNil<T: Equatable>(keyPath: KeyPath<Advertisement, T?>, key: String) {
        var dictionary = self.dictionary
        
        dictionary[key] = nil as T?
        
        let advertisement = Advertisement(dictionary: dictionary)
        let transformed = advertisement[keyPath: keyPath]
        
        XCTAssertEqual(transformed, nil)
    }
}