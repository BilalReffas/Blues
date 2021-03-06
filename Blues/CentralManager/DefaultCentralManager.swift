// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import CoreBluetooth

open class DefaultCentralManager:
    CentralManager, DelegatedCentralManagerProtocol, DataSourcedCentralManagerProtocol
{
    public weak var delegate: CentralManagerDelegate?
    public weak var dataSource: CentralManagerDataSource?
    
    public init(
        delegate: CentralManagerDelegate? = nil,
        queue: DispatchQueue = .global(),
        options: CentralManagerOptions? = nil
    ) {
        self.delegate = delegate
        super.init(queue: queue, options: options)
    }
    
    internal override init(core: CBCentralManagerProtocol) {
        super.init(core: core)
    }
}
