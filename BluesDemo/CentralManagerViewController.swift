//
//  CentralManagerViewController.swift
//  BluesDemo
//
//  Created by Vincent Esche on 28/10/2016.
//  Copyright © 2016 NWTN Berlin. All rights reserved.
//

import UIKit

import Blues

class CentralManagerViewController: UITableViewController {

    enum Section: Int {
        case peripherals

        var title: String {
            switch self {
            case .peripherals:
                return "Peripherals nearby"
            }
        }
    }

    let queue: DispatchQueue = .init(label: "serial")
    var peripheralViewController: PeripheralViewController?
    var centralManager: CentralManager!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed

        self.centralManager = CentralManager(delegate: self, dataSource: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.tableView.reloadData()
    }

    var sortedPeripherals: [Peripheral] = []

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPeripheral" {
            guard let indexPath = self.tableView.indexPathForSelectedRow else {
                return
            }
            let peripherals = self.sortedPeripherals
            let peripheral = peripherals[indexPath.row]

            let controller = (segue.destination as! UINavigationController).topViewController as! PeripheralViewController
            controller.peripheral = peripheral
            controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
            self.peripheralViewController = controller
        }
    }
}

extension CentralManagerViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)!.title
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .peripherals:
            return self.sortedPeripherals.count
        }
    }

    func cellForPeripheral(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PeripheralCell", for: indexPath)

        let peripherals = self.sortedPeripherals
        let peripheral = peripherals[indexPath.row]

        cell.textLabel!.text = peripheral.name ?? "Unnamed"
        cell.detailTextLabel!.text = peripheral.identifier.string

        return cell
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .peripherals:
            return self.cellForPeripheral(at: indexPath)
        }
    }
}

extension CentralManagerViewController: CentralManagerDelegate {

    func willRestore(state: CentralManagerRestoreState, ofManager manager: CentralManager) {
    }

    @available(iOSApplicationExtension 10.0, *)
    func didUpdate(state: CentralManagerState, ofManager manager: CentralManager) {
        self.queue.async {
            self.centralManager.startScanningForPeripherals(advertisingWithServices: nil, options: nil)
        }
    }

    func didDiscover(peripheral: Peripheral, advertisement: Advertisement, rssi: Int, withManager manager: CentralManager) {
        self.queue.async {
            self.sortedPeripherals.append(peripheral)
            self.sortedPeripherals.sort {
                ($0.name ?? $0.identifier.string) < ($1.name ?? $1.identifier.string)
            }
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    func didRetrieve(peripherals: [Peripheral], fromManager manager: CentralManager) {}

    func didRetrieve(connectedPeripherals: [Peripheral], fromManager manager: CentralManager) {}
}

extension CentralManagerViewController: CentralManagerDataSource {

    func discoveredPeripheral(
        shadow: ShadowPeripheral,
        advertisement: Advertisement,
        forCentralManager centralManager: CentralManager
    ) -> Peripheral {
        return DefaultPeripheral(shadow: shadow)
    }

    func restoredPeripheral(
        shadow: ShadowPeripheral,
        forCentralManager centralManager: CentralManager
    ) -> Peripheral {
        return DefaultPeripheral(shadow: shadow)
    }
}
