import Foundation

extension EmulatorSession {
    func prepareNetworkModemForStartup() throws -> Int? {
        let configuration = networkModem.normalized(for: machine)
        guard configuration.isEnabled,
              machine.capabilities.supportsNetworking else {
            hayesModemService.stop()
            networkModemStatus = .disabled
            return nil
        }

        return try hayesModemService.start(configuration: configuration) { [weak self] status in
            Task { @MainActor [weak self] in
                self?.networkModemStatus = status
            }
        }
    }

    func applyNetworkModem(updateStatus: Bool = true) {
        guard machine.capabilities.supportsNetworking else {
            hayesModemService.stop()
            networkModemStatus = .disabled
            return
        }

        let configuration = networkModem.normalized(for: machine)
        guard configuration.isEnabled else {
            hayesModemService.stop()
            networkModemStatus = .disabled
            if engine.isRunning {
                setVICEIntResource("Acia1Enable", value: 0)
                if !syncSystemTime {
                    setVICEIntResource("UserportDevice", value: 0)
                }
            }
            if updateStatus {
                statusText = "Modem off"
            }
            return
        }

        do {
            let localPort = try hayesModemService.start(configuration: configuration) { [weak self] status in
                Task { @MainActor [weak self] in
                    self?.networkModemStatus = status
                }
            }

            guard engine.isRunning else {
                return
            }

            applyNetworkModemResources(configuration: configuration,
                                       localPort: localPort)

            if updateStatus {
                statusText = "Modem \(configuration.interface.shortTitle.lowercased()) ready"
            }
        } catch {
            networkModemStatus = NetworkModemRuntimeStatus(state: .error,
                                                           localPort: nil,
                                                           incomingPort: configuration.acceptsIncomingCalls
                                                           ? configuration.incomingPort
                                                           : nil,
                                                           remoteDescription: nil,
                                                           message: error.localizedDescription)
            if updateStatus {
                statusText = "Modem unavailable"
            }
        }
    }

    private func applyNetworkModemResources(configuration: NetworkModemConfiguration,
                                            localPort: Int) {
        setVICEStringResource("RsDevice3", value: "127.0.0.1:\(localPort)")
        setVICEIntResource("RsDevice3ip232", value: configuration.interface.usesIP232Control ? 1 : 0)

        switch configuration.interface {
        case .userPort:
            setVICEIntResource("Acia1Enable", value: 0)
            setVICEIntResource("UserportDevice", value: 2)
            setVICEIntResource("RsUserDev", value: 2)
            setVICEIntResource("RsUserBaud", value: Int32(configuration.baudRate))
        case .swiftLink, .turbo232:
            if !syncSystemTime {
                setVICEIntResource("UserportDevice", value: 0)
            }
            setVICEIntResource("Acia1Dev", value: 2)
            setVICEIntResource("Acia1Mode", value: configuration.interface.aciaMode ?? 1)
            setVICEIntResource("Acia1Base", value: configuration.aciaBaseAddress.rawValue)
            setVICEIntResource("Acia1Enable", value: 1)
        }
    }
}
