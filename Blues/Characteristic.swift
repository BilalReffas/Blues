//
//  Characteristic.swift
//  Blues
//
//  Created by Vincent Esche on 28/10/2016.
//  Copyright © 2016 NWTN Berlin. All rights reserved.
//

import Foundation
import CoreBluetooth

/// Default implementation of `Characteristic` protocol.
public class DefaultCharacteristic: Characteristic, DelegatedCharacteristic {
    
    public let shadow: ShadowCharacteristic
    
    public weak var delegate: CharacteristicDelegate?

    public required init(shadow: ShadowCharacteristic) {
        self.shadow = shadow
    }
}

extension DefaultCharacteristic: CharacteristicDelegate {

    public func didUpdate(data: Result<Data, Error>, forCharacteristic characteristic: Characteristic) {
        self.delegate?.didUpdate(data: data, forCharacteristic: characteristic)
    }

    public func didWrite(data: Result<Data, Error>, forCharacteristic characteristic: Characteristic) {
        self.delegate?.didWrite(data: data, forCharacteristic: characteristic)
    }

    public func didUpdate(notificationState isNotifying: Result<Bool, Error>, forCharacteristic characteristic: Characteristic) {
        self.delegate?.didUpdate(notificationState: isNotifying, forCharacteristic: characteristic)
    }

    public func didDiscover(descriptors: Result<[Descriptor], Error>, forCharacteristic characteristic: Characteristic) {
        self.delegate?.didDiscover(descriptors: descriptors, forCharacteristic: characteristic)
    }
}

extension DefaultCharacteristic: CustomStringConvertible {
    public var description: String {
        let attributes = [
            "uuid = \(self.uuid)",
            "name = \(self.name ?? "<nil>")",
        ].joined(separator: ", ")
        return "<DefaultCharacteristic \(attributes)>"
    }
}

public protocol Characteristic: class, CharacteristicDelegate {
    
    /// The characteristic's name.
    ///
    /// - Note:
    ///   Default implementation returns `nil`
    var name: String? { get }
    
    /// The supporting "shadow" characteristic that does the heavy lifting.
    var shadow: ShadowCharacteristic { get }

    /// Initializes a `Characteristic` as a shim for a provided shadow characteristic.
    init(shadow: ShadowCharacteristic)

    /// Creates and returns a descriptor for a given shadow descriptor.
    ///
    /// - Note:
    ///   Override this property to provide a custom type for the given descriptor.
    ///   The default implementation creates `DefaultDescriptor`.
    ///
    /// - Parameters:
    ///   - shadow: The descriptor's shadow descriptor.
    ///
    /// - Returns: A new descriptor object.
    func makeDescriptor(shadow: ShadowDescriptor) -> Descriptor
}

public protocol TypesafeCharacteristic: Characteristic {
    associatedtype Value

    /// The value of the descriptor.
    var value: Value? { get }

    func transform(data: Data) -> Value
    func transform(value: Value) -> Data
}

extension Characteristic {
    
    /// The Bluetooth-specific identifier of the characteristic.
    public var uuid: Identifier {
        return self.shadow.uuid
    }

    public var name: String? {
        return nil
    }

    /// The value data of the characteristic.
    public var data: Result<Data?, PeripheralError> {
        return self.core.map { $0.value }
    }

    /// A list of the descriptors that have been discovered in this characteristic.
    ///
    /// - Note:
    ///   The value of this property is an array of `Descriptor` objects that
    ///   represent a characteristic’s descriptors. `Characteristic` descriptors
    ///   provide more information about a characteristic’s value.
    ///   For example, they may describe the value in human-readable form
    ///   and describe how the value should be formatted for presentation purposes.
    ///   For more information about characteristic descriptors, see `Descriptor`.
    public var descriptors: [Identifier: Descriptor]? {
        return self.shadow.descriptors
    }

    /// The properties of the characteristic.
    public var properties: Result<CharacteristicProperties, PeripheralError> {
        return self.core.map {
            CharacteristicProperties(core: $0.properties)
        }
    }

    /// A Boolean value indicating whether the characteristic is
    /// currently notifying a subscribed central of its value.
    public var isNotifying: Result<Bool, PeripheralError> {
        return self.core.map {
            $0.isNotifying
        }
    }

    /// The service that this characteristic belongs to.
    public var service: Service? {
        return self.shadow.service
    }

    var nextResponder: Responder? {
        return self.shadow.service as! Responder?
    }
    
    var core: Result<CBCharacteristic, PeripheralError> {
        return self.shadow.core.okOr(.unreachable)
    }
    
    public func makeDescriptor(shadow: ShadowDescriptor) -> Descriptor {
        return DefaultDescriptor(shadow: shadow)
    }
    
    /// Discovers the descriptors of a characteristic.
    ///
    /// - Note:
    ///   When the characteristic discovers one or more descriptors, it calls the
    ///   `didDiscover(descriptors:forCharacteristic:)` method of its delegate object.
    ///
    /// - Returns: `.ok(())` iff successful, `.err(error)` otherwise.
    public func discoverDescriptors() -> Result<(), PeripheralError> {
        return (self as! Responder).tryToHandle(DiscoverDescriptorsMessage(
            characteristic: self
        )) ?? .err(.unhandled)
    }
    
    /// Retrieves the value of a specified characteristic.
    ///
    /// - Note:
    ///   When you call this method to read the value of a characteristic,
    ///   the peripheral calls the `didUpdate(data:, forCharacteristic:)` method
    ///   of its delegate object.
    ///
    /// - Important:
    ///   Not all characteristics are guaranteed to have a readable value.
    ///   You can determine whether a characteristic’s value is readable
    ///   by accessing the relevant properties of the `CharacteristicProperties`
    ///   enumeration, which are detailed in `Characteristic`.
    ///
    /// - Returns: `.ok(())` iff successful, `.err(error)` otherwise.
    public func read() -> Result<(), PeripheralError> {
        return (self as! Responder).tryToHandle(ReadValueForCharacteristicMessage(
            characteristic: self
        )) ?? .err(.unhandled)
    }

    /// Writes the value of a characteristic.
    ///
    /// - Note:
    ///   When you call this method to write the value of a characteristic,
    ///   it calls the `didWrite(data:, forCharacteristic:)` method of its
    ///   delegate object only if you specified the write type as withResponse.
    ///   The response you receive through the `didWrite(data:, forCharacteristic:)`
    ///   delegate method indicates whether the write was successful;
    ///   if the write failed, it details the cause of the failure in an error.
    ///   If you specify the write type as `.withoutResponse`,
    ///   the write is best-effort and not guaranteed. If the write does not succeed
    ///   in this case, you are not notified nor do you receive an error indicating
    ///   the cause of the failure. The data passed into the data parameter is copied,
    ///   and you can dispose of it after the method returns.
    ///
    /// - Important:
    ///   Characteristics may allow only certain type of writes to be
    ///   performed on their value. To determine which types of writes are permitted
    ///   to a characteristic’s value, you access the relevant properties of the
    ///   `CharacteristicProperties` enumeration, which are detailed in `Characteristic`.
    ///
    /// - Parameters:
    ///   - data: The value to be written.
    ///   - type: The type of write to be executed.
    ///
    /// - Returns: `.ok(())` iff successful, `.err(error)` otherwise.
    public func write(data: Data, type: WriteType) -> Result<(), PeripheralError> {
        return (self as! Responder).tryToHandle(WriteValueForCharacteristicMessage(
            data: data,
            characteristic: self,
            type: type
        )) ?? .err(.unhandled)
    }

    /// Sets notifications or indications for the value of a specified characteristic.
    ///
    /// - Note:
    ///   When you enable notifications for the characteristic’s value,
    ///   the peripheral calls the `func didUpdate(notificationState:forCharacteristic:)`
    ///   method of its delegate object to indicate whether or not the action succeeded.
    ///   If successful, the peripheral then calls the `didUpdate(data:, forCharacteristic:)`
    ///   method of its delegate object whenever the characteristic value changes.
    ///   Because it is the peripheral that chooses when to send an update,
    ///   your app should be prepared to handle them as long as notifications
    ///   or indications remain enabled. If the specified characteristic is configured
    ///   to allow both notifications and indications, calling this method enables notifications only.
    ///   You can disable notifications and indications for a characteristic’s value
    ///   by calling this method with the enabled parameter set to `false`.
    ///
    /// - Parameter notifyValue:
    ///   A Boolean value indicating whether you wish to
    ///   receive notifications or indications whenever the characteristic’s
    ///   value changes. `true` if you want to enable notifications or indications
    ///   for the characteristic’s value. `false` if you do not want to receive
    ///   notifications or indications whenever the characteristic’s value changes.
    ///
    /// - Returns: `.ok(())` iff successful, `.err(error)` otherwise.
    public func set(notifyValue: Bool) -> Result<(), PeripheralError> {
        return (self as! Responder).tryToHandle(SetNotifyValueForCharacteristicMessage(
            notifyValue: notifyValue,
            characteristic: self
        )) ?? .err(.unhandled)
    }
}

extension TypesafeCharacteristic {
    /// The value of the characteristic.
    ///
    /// - Note:
    ///   This is a thin type-safe wrapper around `Characteristic.data`.
    ///   See its documentation for more information. All this wrapper basically
    ///   does is transforming `self.data` into an `Value` object by calling
    ///   `self.transform(data: self.data)` and then returning the result.
    public var value: Result<Value?, PeripheralError> {
        return self.data.andThen {
            .ok($0.map { self.transform(data: $0) })
        }
    }

    /// Writes the value of a characteristic.
    ///
    /// - Note:
    ///   This is a thin type-safe wrapper around `Characteristic.write(data:type:)`.
    ///   See its documentation for more information. All this wrapper basically does
    ///   is transforming `value` into an `Data` object by calling `self.transform(value: value)`
    ///   and then passing the result to `Characteristic.write(data:type:)`.
    ///
    /// - SeeAlso: `Characteristic.write(data:type:)`
    ///
    /// - Parameters:
    ///   - data: The value to be written.
    ///   - type: The type of write to be executed.
    ///
    /// - Returns: `.ok(())` iff successful, `.err(error)` otherwise.
    public func write(value: Value, type: WriteType) -> Result<(), PeripheralError> {
        return (self as! Responder).tryToHandle(WriteValueForCharacteristicMessage(
            data: self.transform(value: value),
            characteristic: self,
            type: type
        )) ?? .err(.unhandled)
    }
}

/// A `Characteristic` that supports delegation.
public protocol DelegatedCharacteristic: Characteristic {
    
    /// The characteristic's delegate.
    weak var delegate: CharacteristicDelegate? { get set }
}

/// A `DelegatedCharacteristic`'s delegate.
public protocol CharacteristicDelegate: class {
    
    /// Invoked when you retrieve a specified characteristic’s value,
    /// or when the peripheral device notifies your app that
    /// the characteristic’s value has changed.
    ///
    /// - Parameters:
    ///   - data: `.ok(data)` with the updated value iff successful, otherwise `.err(error)`.
    ///   - characteristic: The characteristic whose value has been retrieved.
    func didUpdate(data: Result<Data, Error>, forCharacteristic characteristic: Characteristic)
    
    /// Invoked when you write data to a characteristic’s value.
    ///
    /// - Note:
    ///   This method is invoked only when your app calls the `write(data:type:)` or
    ///   `write(value:type:)` method with `.withResponse` specified as the write type.
    ///
    /// - Parameters:
    ///   - data: `.ok(data)` with the written value iff successful, otherwise `.err(error)`.
    ///   - characteristic: The characteristic whose value has been retrieved.
    func didWrite(data: Result<Data, Error>, forCharacteristic characteristic: Characteristic)
    
    /// Invoked when the peripheral receives a request to start or stop providing
    /// notifications for a specified characteristic’s value.
    ///
    /// - Note:
    ///   This method is invoked when your app calls the set(notifyValue:for:) method.
    ///
    /// - Parameters:
    ///   - isNotifying: `.ok(flag)` with a boolean value indicating whether the
    ///     characteristic is currently notifying a subscribed central of its
    ///     value iff successful, otherwise `.err(error)`.
    ///   - characteristic: The characteristic whose notification state has been retrieved.
    func didUpdate(notificationState isNotifying: Result<Bool, Error>, forCharacteristic characteristic: Characteristic)

    /// Invoked when you discover the descriptors of a specified characteristic.
    ///
    /// - Note:
    ///   This method is invoked when your app calls the discoverDescriptors() method.
    ///
    /// - Parameters:
    ///   - descriptors: `.ok(descriptors)` with the character descriptors that
    ///     were discovered, iff successful, otherwise `.ok(error)`.
    ///   - characteristic: The characteristic that the characteristic descriptors belong to.
    func didDiscover(descriptors: Result<[Descriptor], Error>, forCharacteristic characteristic: Characteristic)
}

public protocol TypesafeCharacteristicDelegate: CharacteristicDelegate {
    /// The characteristic value's type.
    associatedtype Value

    /// Invoked when you retrieve a specified characteristic’s value,
    /// or when the peripheral device notifies your app that
    /// the characteristic’s value has changed.
    ///
    /// - Note:
    ///   This is a thin type-safe wrapper around `Characteristic.didUpdate(data:forCharacteristic:)`.
    ///   See its documentation for more information. All this wrapper basically
    ///   does is transforming `self.data` into an `Value` object by calling
    ///   `self.transform(data: self.data)` and then returning the result.
    ///
    /// - SeeAlso: `CharacteristicDelegate.didUpdate(data:forCharacteristic:)`
    ///
    /// - Parameters:
    ///   - data: `.ok(data)` with the updated value iff successful, otherwise `.err(error)`.
    ///   - characteristic: The characteristic whose value has been retrieved.
    func didUpdate(value: Result<Value, Error>, forCharacteristic characteristic: Characteristic)
    
    /// Invoked when you write data to a characteristic’s value.
    ///
    /// - SeeAlso: `CharacteristicDelegate.didWrite(data:forCharacteristic:)`
    ///
    /// - Note:
    ///   This is a thin type-safe wrapper around `Characteristic.didWrite(data:forCharacteristic:)`.
    ///   See its documentation for more information. All this wrapper basically
    ///   does is transforming `self.data` into an `Value` object by calling
    ///   `self.transform(data: self.data)` and then returning the result.
    ///
    /// - Important:
    ///   This method is invoked only when your app calls the `write(data:type:)` or
    ///   `write(value:type:)` method with `.withResponse` specified as the write type.
    ///
    /// - Parameters:
    ///   - data: `.ok(data)` with the written value iff successful, otherwise `.err(error)`.
    ///   - characteristic: The characteristic whose value has been retrieved.
    func didWrite(value: Result<Value, Error>, forCharacteristic characteristic: Characteristic)
}

/// The supporting "shadow" characteristic that does the actual heavy lifting
/// behind any `Characteristic` implementation.
public class ShadowCharacteristic {
    
    /// The Bluetooth-specific identifier of the characteristic.
    public let uuid: Identifier
    
    weak var core: CBCharacteristic?
    weak var service: Service?
    var descriptors: [Identifier: Descriptor] = [:]

    init(core: CBCharacteristic, service: Service) {
        self.uuid = Identifier(uuid: core.uuid)
        self.core = core
        self.service = service
    }

    func attach(core: CBCharacteristic) {
        self.core = core
        guard let cores = core.descriptors else {
            return
        }
        for core in cores {
            let uuid = Identifier(uuid: core.uuid)
            guard let descriptor = self.descriptors[uuid] else {
                continue
            }
            descriptor.shadow.attach(core: core)
        }
    }

    func detach() {
        self.core = nil
        for descriptor in self.descriptors.values {
            descriptor.shadow.detach()
        }
    }
}
