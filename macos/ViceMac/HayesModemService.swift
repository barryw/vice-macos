import Darwin
import Foundation
@preconcurrency import Network

private enum HayesModemServiceError: LocalizedError {
    case portReservationUnavailable
    case invalidIncomingPort(Int)
    case listenerUnavailable

    var errorDescription: String? {
        switch self {
        case .portReservationUnavailable:
            return "A local modem port could not be reserved."
        case let .invalidIncomingPort(port):
            return "Port \(port) is not available for incoming calls."
        case .listenerUnavailable:
            return "The local modem socket could not be created."
        }
    }
}

private enum HayesModemResult {
    case ok
    case connect(Int)
    case ring
    case noCarrier
    case error

    var numericCode: String {
        switch self {
        case .ok:
            return "0"
        case .connect:
            return "1"
        case .ring:
            return "2"
        case .noCarrier:
            return "3"
        case .error:
            return "4"
        }
    }

    var text: String {
        switch self {
        case .ok:
            return "OK"
        case let .connect(baudRate):
            return "CONNECT \(baudRate)"
        case .ring:
            return "RING"
        case .noCarrier:
            return "NO CARRIER"
        case .error:
            return "ERROR"
        }
    }

    func text(connectResultIncludesBaudRate: Bool) -> String {
        switch self {
        case let .connect(baudRate):
            return connectResultIncludesBaudRate ? "CONNECT \(baudRate)" : "CONNECT"
        default:
            return text
        }
    }
}

private enum HayesDialTarget {
    case testLine
    case tcp(host: String, port: NWEndpoint.Port)
}

private final class HayesModemListenerStartup: @unchecked Sendable {
    let semaphore = DispatchSemaphore(value: 0)

    private let lock = NSLock()
    private var result: Result<Void, Error>?

    func succeed() {
        finish(.success(()))
    }

    func fail(_ error: Error) {
        finish(.failure(error))
    }

    func wait(timeout: DispatchTime) -> Result<Void, Error>? {
        guard semaphore.wait(timeout: timeout) == .success else {
            return nil
        }

        lock.lock()
        defer {
            lock.unlock()
        }

        return result
    }

    private func finish(_ result: Result<Void, Error>) {
        lock.lock()
        let shouldSignal = self.result == nil
        if shouldSignal {
            self.result = result
        }
        lock.unlock()

        if shouldSignal {
            semaphore.signal()
        }
    }
}

final class HayesModemService: @unchecked Sendable {
    private static let defaultDialTimeout: DispatchTimeInterval = .seconds(15)
    private static let listenerStartupAttempts = 8
    private static let listenerStartupTimeout: DispatchTimeInterval = .milliseconds(750)
    private static let ip232Magic: UInt8 = 0xff
    private static let ip232CarrierDetect: UInt8 = 0x01
    private static let ip232RingIndicator: UInt8 = 0x02
    private static let telnetIAC: UInt8 = 255
    private static let telnetWILL: UInt8 = 251
    private static let telnetWONT: UInt8 = 252
    private static let telnetDO: UInt8 = 253
    private static let telnetDONT: UInt8 = 254
    private static let commandDeleteBytes: Set<UInt8> = [8, 20, 127]

    private let queue = DispatchQueue(label: "com.barrywalker.vicemac.hayes-modem")
    private let listenerQueue = DispatchQueue(label: "com.barrywalker.vicemac.hayes-modem.listener")
    private var configuration = NetworkModemConfiguration.standard
    private var statusHandler: ((NetworkModemRuntimeStatus) -> Void)?
    private var localListener: NWListener?
    private var incomingListener: NWListener?
    private var localPort: Int?
    private var serialConnection: NWConnection?
    private var remoteConnection: NWConnection?
    private var pendingIncomingConnection: NWConnection?
    private var activeTestLine = false
    private var remoteDescription: String?
    private var commandBuffer = ""
    private var testLineBuffer = ""
    private var waitingForIP232Byte = false
    private var waitingForTelnetCommand: UInt8?
    private var waitingForTelnetOption = false
    private var carrierDetect = false
    private var ringIndicator = false
    private var online = false
    private var echoMode = true
    private var verboseMode = true
    private var quietMode = false
    private var autoAnswerRings = 0
    private var ringCount = 0
    private var ringTimer: DispatchSourceTimer?
    private var dialTimer: DispatchSourceTimer?
    private let dialTimeout: DispatchTimeInterval
    private var protocolCapture: QLinkProtocolCapture?

    init(dialTimeout: DispatchTimeInterval = HayesModemService.defaultDialTimeout) {
        self.dialTimeout = dialTimeout
    }

    @discardableResult
    static func applyCommandEditingByte(_ byte: UInt8, to buffer: inout String) -> Bool {
        if commandDeleteBytes.contains(byte) {
            if !buffer.isEmpty {
                buffer.removeLast()
            }
            return true
        }

        guard buffer.count < 512,
              let scalar = UnicodeScalar(Int(byte)) else {
            return false
        }

        buffer.append(Character(scalar))
        return true
    }

    func start(configuration: NetworkModemConfiguration,
               statusHandler: @escaping (NetworkModemRuntimeStatus) -> Void) throws -> Int {
        try queue.sync {
            if let localListener,
               let localPort,
               self.configuration == configuration {
                self.statusHandler = statusHandler
                publishCurrentStatus()
                _ = localListener
                return localPort
            }

            stopOnQueue(publish: false)
            self.configuration = configuration
            self.statusHandler = statusHandler
            echoMode = configuration.echoCommands
            verboseMode = configuration.verboseResultCodes
            quietMode = false
            autoAnswerRings = configuration.autoAnswerRings

            let localSocket = try makeLocalListener()
            localListener = localSocket.listener
            localPort = Int(localSocket.port.rawValue)

            if configuration.acceptsIncomingCalls {
                incomingListener = try makeIncomingListener(port: configuration.incomingPort)
            }

            publishCurrentStatus(message: "Local modem socket on port \(localSocket.port.rawValue)")
            return Int(localSocket.port.rawValue)
        }
    }

    func stop() {
        queue.sync {
            stopOnQueue(publish: true)
        }
    }

    /// Begin writing Q-Link protocol captures. `url` is the human-readable log;
    /// a raw binary `.cap` with the same basename is written beside it.
    func startProtocolCapture(to url: URL) {
        queue.async {
            self.protocolCapture?.close()
            self.protocolCapture = QLinkProtocolCapture(logURL: url)
        }
    }

    func stopProtocolCapture() {
        queue.async {
            self.protocolCapture?.close()
            self.protocolCapture = nil
        }
    }

    private static func reserveLocalPort() throws -> NWEndpoint.Port {
        let descriptor = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard descriptor >= 0 else {
            throw HayesModemServiceError.portReservationUnavailable
        }
        defer {
            close(descriptor)
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        var bindAddress = address
        let bindResult = withUnsafePointer(to: &bindAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                Darwin.bind(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw HayesModemServiceError.portReservationUnavailable
        }

        var boundAddress = sockaddr_in()
        var boundAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                getsockname(descriptor, socketAddress, &boundAddressLength)
            }
        }
        guard nameResult == 0 else {
            throw HayesModemServiceError.portReservationUnavailable
        }

        let port = UInt16(bigEndian: boundAddress.sin_port)
        guard let endpointPort = NWEndpoint.Port(rawValue: port),
              port != 0 else {
            throw HayesModemServiceError.portReservationUnavailable
        }

        return endpointPort
    }

    private func makeLocalListener() throws -> (listener: NWListener, port: NWEndpoint.Port) {
        var lastFailure: Error?

        for _ in 0..<Self.listenerStartupAttempts {
            let reservedPort = try Self.reserveLocalPort()
            let listener = try NWListener(using: .tcp, on: reservedPort)
            let startup = HayesModemListenerStartup()

            listener.newConnectionHandler = { [weak self] connection in
                guard let service = self else {
                    return
                }

                service.queue.async {
                    service.acceptSerialConnection(connection)
                }
            }
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                switch state {
                case .ready:
                    startup.succeed()
                case let .failed(error):
                    startup.fail(error)
                default:
                    break
                }

                guard let service = self else {
                    return
                }

                service.queue.async { [weak listener] in
                    guard let listener,
                          service.localListener === listener else {
                        return
                    }

                    service.handleLocalListenerState(state)
                }
            }
            listener.start(queue: listenerQueue)

            switch startup.wait(timeout: .now() + Self.listenerStartupTimeout) {
            case .success:
                return (listener, reservedPort)
            case let .failure(error):
                lastFailure = error
            case nil:
                lastFailure = HayesModemServiceError.listenerUnavailable
            }

            listener.cancel()
        }

        if let lastFailure {
            throw lastFailure
        }

        throw HayesModemServiceError.portReservationUnavailable
    }

    private func stopOnQueue(publish: Bool) {
        ringTimer?.cancel()
        dialTimer?.cancel()
        ringTimer = nil
        dialTimer = nil
        localListener?.cancel()
        incomingListener?.cancel()
        serialConnection?.cancel()
        remoteConnection?.cancel()
        pendingIncomingConnection?.cancel()
        localListener = nil
        incomingListener = nil
        localPort = nil
        serialConnection = nil
        remoteConnection = nil
        pendingIncomingConnection = nil
        activeTestLine = false
        remoteDescription = nil
        commandBuffer = ""
        testLineBuffer = ""
        waitingForIP232Byte = false
        waitingForTelnetCommand = nil
        waitingForTelnetOption = false
        carrierDetect = false
        ringIndicator = false
        online = false
        ringCount = 0

        if publish {
            statusHandler?(.disabled)
        }
    }

    private func makeIncomingListener(port: Int) throws -> NWListener {
        guard let rawPort = UInt16(exactly: port),
              let endpointPort = NWEndpoint.Port(rawValue: rawPort) else {
            throw HayesModemServiceError.invalidIncomingPort(port)
        }

        let listener = try NWListener(using: .tcp, on: endpointPort)
        listener.newConnectionHandler = { [weak self] connection in
            guard let service = self else {
                return
            }

            service.queue.async {
                service.acceptIncomingCall(connection)
            }
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let service = self else {
                return
            }

            service.queue.async {
                service.handleIncomingListenerState(state)
            }
        }
        listener.start(queue: queue)
        return listener
    }

    private func handleLocalListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            publishCurrentStatus()
        case let .failed(error):
            publishError(error.localizedDescription)
        default:
            break
        }
    }

    private func handleIncomingListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            publishCurrentStatus()
        case let .failed(error):
            publishError(error.localizedDescription)
        default:
            break
        }
    }

    private func acceptSerialConnection(_ connection: NWConnection) {
        serialConnection?.cancel()
        serialConnection = connection
        commandBuffer = ""
        waitingForIP232Byte = false

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let service = self,
                  let connection else {
                return
            }

            service.queue.async {
                service.handleSerialState(state, connection: connection)
            }
        }
        connection.start(queue: queue)
        receiveSerial(on: connection)
        sendIP232Status()
        publishCurrentStatus()

        if pendingIncomingConnection != nil {
            beginRinging()
        }
    }

    private func handleSerialState(_ state: NWConnection.State,
                                   connection: NWConnection) {
        guard serialConnection === connection else {
            return
        }

        switch state {
        case .ready:
            publishCurrentStatus()
            sendIP232Status()
        case .cancelled, .failed:
            serialConnection = nil
            publishCurrentStatus()
        default:
            break
        }
    }

    private func acceptIncomingCall(_ connection: NWConnection) {
        guard pendingIncomingConnection == nil,
              remoteConnection == nil else {
            connection.cancel()
            return
        }

        pendingIncomingConnection = connection
        remoteDescription = endpointDescription(connection.endpoint)
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let service = self,
                  let connection else {
                return
            }

            service.queue.async {
                service.handlePendingIncomingState(state, connection: connection)
            }
        }
        connection.start(queue: queue)
        beginRinging()
    }

    private func handlePendingIncomingState(_ state: NWConnection.State,
                                            connection: NWConnection) {
        guard pendingIncomingConnection === connection else {
            return
        }

        switch state {
        case .failed, .cancelled:
            pendingIncomingConnection = nil
            stopRinging()
            publishCurrentStatus()
        default:
            break
        }
    }

    private func receiveSerial(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1,
                           maximumLength: 4096) { [weak self, weak connection] data, _, isComplete, error in
            guard let self,
                  let connection else {
                return
            }

            self.queue.async {
                guard self.serialConnection === connection else {
                    return
                }

                if let data,
                   !data.isEmpty {
                    self.handleSerialBytes(Array(data))
                }

                if isComplete || error != nil {
                    self.serialConnection = nil
                    self.publishCurrentStatus()
                } else {
                    self.receiveSerial(on: connection)
                }
            }
        }
    }

    private func receiveRemote(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1,
                           maximumLength: 4096) { [weak self, weak connection] data, _, isComplete, error in
            guard let self,
                  let connection else {
                return
            }

            self.queue.async {
                guard self.remoteConnection === connection else {
                    return
                }

                if let data,
                   !data.isEmpty {
                    self.protocolCapture?.record(direction: 1, bytes: Array(data))
                    let bytes = self.bytesForSerial(fromRemoteBytes: Array(data))
                    self.sendSerialData(bytes)
                }

                if isComplete || error != nil {
                    self.disconnectRemote(sendNoCarrier: true)
                } else {
                    self.receiveRemote(on: connection)
                }
            }
        }
    }

    private func handleSerialBytes(_ bytes: [UInt8]) {
        for byte in bytes {
            if configuration.interface.usesIP232Control {
                if waitingForIP232Byte {
                    handleIP232Byte(byte)
                    waitingForIP232Byte = false
                    continue
                }

                if byte == Self.ip232Magic {
                    waitingForIP232Byte = true
                    continue
                }
            }

            if online {
                sendRemoteData([byte])
            } else {
                handleCommandByte(byte)
            }
        }
    }

    private func handleIP232Byte(_ byte: UInt8) {
        guard byte != Self.ip232Magic else {
            if online {
                sendRemoteData([Self.ip232Magic])
            } else {
                handleCommandByte(Self.ip232Magic)
            }
            return
        }

        let dataTerminalReady = (byte & 0x01) != 0
        if !dataTerminalReady,
           carrierDetect || online {
            disconnectRemote(sendNoCarrier: true)
        }
    }

    private func handleCommandByte(_ byte: UInt8) {
        switch byte {
        case _ where Self.commandDeleteBytes.contains(byte):
            Self.applyCommandEditingByte(byte, to: &commandBuffer)
            if echoMode {
                sendSerialData([byte])
            }
        case 10:
            break
        case 13:
            if echoMode {
                sendSerialData([13, 10])
            }
            executeCommand(commandBuffer)
            commandBuffer = ""
        default:
            if echoMode {
                sendSerialData([byte])
            }
            Self.applyCommandEditingByte(byte, to: &commandBuffer)
        }
    }

    private func executeCommand(_ command: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCommand.uppercased().hasPrefix("AT") else {
            sendResult(.error)
            return
        }

        var body = String(trimmedCommand.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else {
            sendResult(.ok)
            return
        }

        while let first = body.uppercased().first {
            switch first {
            case "Z":
                resetCommandModeSettings()
                body.removeFirst()
            case "E":
                let value = consumeNumericSuffix(from: &body, afterCommand: "E")
                echoMode = value != 0
            case "Q":
                let value = consumeNumericSuffix(from: &body, afterCommand: "Q")
                quietMode = value != 0
            case "V":
                let value = consumeNumericSuffix(from: &body, afterCommand: "V")
                verboseMode = value != 0
            case "I":
                body.removeFirst()
                sendLine("mac VICE Hayes modem")
            case "H":
                _ = consumeNumericSuffix(from: &body, afterCommand: "H")
                disconnectRemote(sendNoCarrier: false)
            case "O":
                body.removeFirst()
                guard remoteConnection != nil || activeTestLine else {
                    sendResult(.noCarrier)
                    return
                }
                online = true
                sendResult(.connect(configuration.baudRate))
                return
            case "A":
                body.removeFirst()
                answerIncomingCall()
                return
            case "D":
                body.removeFirst()
                dial(String(body))
                return
            case "S":
                handleRegisterCommand(&body)
            default:
                body.removeFirst()
                while let next = body.first,
                      next.isNumber {
                    body.removeFirst()
                }
            }
        }

        sendResult(.ok)
    }

    private func consumeNumericSuffix(from body: inout String,
                                      afterCommand command: Character) -> Int {
        guard body.uppercased().first == command else {
            return 0
        }

        body.removeFirst()
        var digits = ""
        while let next = body.first,
              next.isNumber {
            digits.append(next)
            body.removeFirst()
        }

        return Int(digits) ?? 1
    }

    private func handleRegisterCommand(_ body: inout String) {
        guard body.uppercased().hasPrefix("S") else {
            return
        }

        body.removeFirst()
        var registerDigits = ""
        while let next = body.first,
              next.isNumber {
            registerDigits.append(next)
            body.removeFirst()
        }

        guard registerDigits == "0" else {
            return
        }

        if body.first == "=" {
            body.removeFirst()
            var valueDigits = ""
            while let next = body.first,
                  next.isNumber {
                valueDigits.append(next)
                body.removeFirst()
            }
            autoAnswerRings = min(max(Int(valueDigits) ?? 0, 0), 9)
        }
    }

    private func resetCommandModeSettings() {
        echoMode = configuration.echoCommands
        verboseMode = configuration.verboseResultCodes
        quietMode = false
        autoAnswerRings = configuration.autoAnswerRings
    }

    private func dial(_ rawTarget: String) {
        guard let target = parseDialTarget(rawTarget) else {
            sendResult(.error)
            return
        }

        switch target {
        case .testLine:
            connectTestLine()
        case let .tcp(host, port):
            dialTCP(host: host, port: port)
        }
    }

    private func dialTCP(host: String, port: NWEndpoint.Port) {
        disconnectRemote(sendNoCarrier: false)
        let connection = NWConnection(host: NWEndpoint.Host(host),
                                      port: port,
                                      using: .tcp)
        remoteConnection = connection
        remoteDescription = "\(host):\(port.rawValue)"
        online = false
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let service = self,
                  let connection else {
                return
            }

            service.queue.async {
                service.handleRemoteState(state, connection: connection)
            }
        }
        connection.start(queue: queue)
        scheduleDialTimeout(for: connection,
                            host: host,
                            port: port)
        publishCurrentStatus(message: "Dialing \(host):\(port.rawValue)")
    }

    private func scheduleDialTimeout(for connection: NWConnection,
                                     host: String,
                                     port: NWEndpoint.Port) {
        dialTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + dialTimeout)
        timer.setEventHandler { [weak self, weak connection] in
            guard let self,
                  let connection,
                  self.remoteConnection === connection,
                  !self.online else {
                return
            }

            self.remoteConnection = nil
            self.remoteDescription = nil
            self.dialTimer = nil
            connection.cancel()
            self.setCarrierDetect(false)
            self.sendResult(.noCarrier)
            self.publishCurrentStatus(message: "Dial timed out calling \(host):\(port.rawValue)")
        }
        dialTimer = timer
        timer.resume()
    }

    private func connectTestLine() {
        disconnectRemote(sendNoCarrier: false)
        activeTestLine = true
        remoteDescription = "mac VICE test line"
        online = true
        testLineBuffer = ""
        setCarrierDetect(true)
        sendResult(.connect(configuration.baudRate))
        sendTestLineLines([
            "mac VICE MODEM TEST LINE",
            "TYPE HELP FOR COMMANDS.",
            "TYPE BYE TO HANG UP."
        ])
        publishCurrentStatus()
    }

    private func handleRemoteState(_ state: NWConnection.State,
                                   connection: NWConnection) {
        guard remoteConnection === connection else {
            return
        }

        switch state {
        case .ready:
            dialTimer?.cancel()
            dialTimer = nil
            online = true
            setCarrierDetect(true)
            sendResult(.connect(configuration.baudRate))
            receiveRemote(on: connection)
            publishCurrentStatus()
        case let .failed(error):
            dialTimer?.cancel()
            dialTimer = nil
            remoteConnection = nil
            online = false
            setCarrierDetect(false)
            sendResult(.noCarrier)
            publishCurrentStatus(message: error.localizedDescription)
        case .cancelled:
            dialTimer?.cancel()
            dialTimer = nil
            remoteConnection = nil
            online = false
            setCarrierDetect(false)
            sendResult(.noCarrier)
            publishCurrentStatus()
        default:
            break
        }
    }

    private func answerIncomingCall() {
        guard let connection = pendingIncomingConnection else {
            sendResult(.noCarrier)
            return
        }

        pendingIncomingConnection = nil
        remoteConnection = connection
        stopRinging()
        online = true
        setCarrierDetect(true)
        receiveRemote(on: connection)
        sendResult(.connect(configuration.baudRate))
        publishCurrentStatus()
    }

    private func disconnectRemote(sendNoCarrier: Bool) {
        dialTimer?.cancel()
        dialTimer = nil
        let connection = remoteConnection
        remoteConnection = nil
        pendingIncomingConnection?.cancel()
        pendingIncomingConnection = nil
        connection?.cancel()
        activeTestLine = false
        testLineBuffer = ""
        remoteDescription = nil
        stopRinging()
        online = false
        setCarrierDetect(false)

        if sendNoCarrier {
            sendResult(.noCarrier)
        }

        publishCurrentStatus()
    }

    private func parseDialTarget(_ rawTarget: String) -> HayesDialTarget? {
        var target = rawTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        if isTestLineTarget(target) {
            return .testLine
        }

        if let first = target.first,
           first == "T" || first == "t" || first == "P" || first == "p" {
            target.removeFirst()
            target = target.trimmingCharacters(in: .whitespaces)
        }
        if isTestLineTarget(target) {
            return .testLine
        }

        if target.uppercased().hasPrefix("TELNET://") {
            target.removeFirst("telnet://".count)
        }

        if let terminatorIndex = target.firstIndex(where: { $0 == ";" || $0 == "," || $0 == " " }) {
            target = String(target[..<terminatorIndex])
        }

        target = target.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !target.isEmpty else {
            return nil
        }

        if let host = defaultHostForTelephoneDialTarget(target),
           let port = NWEndpoint.Port(rawValue: UInt16(configuration.defaultDialPort)) {
            return .tcp(host: host, port: port)
        }

        let host: String
        let portNumber: Int
        if let separator = target.lastIndex(of: ":"),
           let parsedPort = Int(target[target.index(after: separator)...]) {
            host = String(target[..<separator])
            portNumber = parsedPort
        } else {
            host = target
            portNumber = configuration.defaultDialPort
        }

        guard !host.isEmpty,
              let rawPort = UInt16(exactly: portNumber),
              let port = NWEndpoint.Port(rawValue: rawPort) else {
            return nil
        }

        return .tcp(host: host, port: port)
    }

    private func defaultHostForTelephoneDialTarget(_ target: String) -> String? {
        let host = configuration.defaultDialHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else {
            return nil
        }

        var hasDigit = false
        for scalar in target.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar) {
                hasDigit = true
                continue
            }

            guard CharacterSet(charactersIn: "+-(). /").contains(scalar) else {
                return nil
            }
        }

        return hasDigit ? host : nil
    }

    private func isTestLineTarget(_ target: String) -> Bool {
        let normalizedTarget = target
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            .uppercased()

        return normalizedTarget == "TEST"
            || normalizedTarget == "MACVICE"
            || normalizedTarget == "MACVICE.TEST"
    }

    private func beginRinging() {
        guard pendingIncomingConnection != nil else {
            return
        }

        ringCount = 0
        ringTimer?.cancel()
        ringTimer = DispatchSource.makeTimerSource(queue: queue)
        ringTimer?.schedule(deadline: .now(),
                            repeating: .seconds(3),
                            leeway: .milliseconds(250))
        ringTimer?.setEventHandler { [weak self] in
            self?.sendRing()
        }
        ringTimer?.resume()
    }

    private func sendRing() {
        guard pendingIncomingConnection != nil else {
            stopRinging()
            return
        }

        ringCount += 1
        setRingIndicator(true)
        sendResult(.ring)
        queue.asyncAfter(deadline: .now() + .milliseconds(850)) { [weak self] in
            self?.setRingIndicator(false)
        }
        publishCurrentStatus()

        if autoAnswerRings > 0,
           ringCount >= autoAnswerRings {
            answerIncomingCall()
        }
    }

    private func stopRinging() {
        ringTimer?.cancel()
        ringTimer = nil
        ringCount = 0
        setRingIndicator(false)
    }

    private func setCarrierDetect(_ enabled: Bool) {
        guard carrierDetect != enabled else {
            return
        }

        carrierDetect = enabled
        sendIP232Status()
    }

    private func setRingIndicator(_ enabled: Bool) {
        guard ringIndicator != enabled else {
            return
        }

        ringIndicator = enabled
        sendIP232Status()
    }

    private func sendResult(_ result: HayesModemResult) {
        guard !quietMode else {
            return
        }

        if verboseMode {
            sendLine(result.text(connectResultIncludesBaudRate: configuration.connectResultIncludesBaudRate))
        } else {
            sendLine(result.numericCode)
        }
    }

    private func sendLine(_ line: String) {
        guard let data = "\r\n\(line)\r\n".data(using: .ascii) else {
            return
        }

        sendSerialData(Array(data))
    }

    private func sendSerialData(_ bytes: [UInt8]) {
        guard configuration.interface.usesIP232Control else {
            sendSerialRaw(bytes)
            return
        }

        var escapedBytes: [UInt8] = []
        escapedBytes.reserveCapacity(bytes.count)

        for byte in bytes {
            escapedBytes.append(byte)
            if byte == Self.ip232Magic {
                escapedBytes.append(Self.ip232Magic)
            }
        }

        sendSerialRaw(escapedBytes)
    }

    private func sendIP232Status() {
        guard configuration.interface.usesIP232Control else {
            return
        }

        var status: UInt8 = 0
        if carrierDetect {
            status |= Self.ip232CarrierDetect
        }
        if ringIndicator {
            status |= Self.ip232RingIndicator
        }

        sendSerialRaw([Self.ip232Magic, status])
    }

    private func sendSerialRaw(_ bytes: [UInt8]) {
        guard let serialConnection,
              !bytes.isEmpty else {
            return
        }

        serialConnection.send(content: Data(bytes), completion: .contentProcessed { _ in })
    }

    private func sendRemoteData(_ bytes: [UInt8]) {
        if activeTestLine {
            handleTestLineBytes(bytes)
            return
        }

        guard let remoteConnection,
              !bytes.isEmpty else {
            return
        }

        protocolCapture?.record(direction: 0, bytes: bytes)

        let payload: [UInt8]
        if configuration.transportMode == .telnet {
            payload = bytes.flatMap { byte in
                byte == Self.telnetIAC ? [Self.telnetIAC, Self.telnetIAC] : [byte]
            }
        } else {
            payload = bytes
        }

        remoteConnection.send(content: Data(payload), completion: .contentProcessed { _ in })
    }

    private func handleTestLineBytes(_ bytes: [UInt8]) {
        for byte in bytes {
            switch byte {
            case 8, 127:
                if !testLineBuffer.isEmpty {
                    testLineBuffer.removeLast()
                }
                sendSerialData([8, 32, 8])
            case 10:
                break
            case 13:
                sendSerialData([13, 10])
                executeTestLineCommand(testLineBuffer)
                testLineBuffer = ""
            default:
                guard let scalar = UnicodeScalar(Int(byte)),
                      byte >= 32,
                      byte <= 126 else {
                    continue
                }

                if testLineBuffer.count < 512 {
                    testLineBuffer.append(Character(scalar))
                }
                sendSerialData([byte])
            }
        }
    }

    private func executeTestLineCommand(_ command: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let uppercasedCommand = trimmedCommand.uppercased()

        switch uppercasedCommand {
        case "":
            sendTestLinePrompt()
        case "HELP", "?":
            sendTestLineLines([
                "COMMANDS:",
                "  HELP  SHOW THIS MENU",
                "  PING  CHECK ROUND TRIP DATA",
                "  TIME  SHOW MAC HOST TIME",
                "  ECHO TEXT  ECHO TEXT BACK",
                "  BYE   HANG UP"
            ])
        case "PING":
            sendTestLineLines(["PONG"])
        case "TIME":
            let timestamp = ISO8601DateFormatter().string(from: Date())
            sendTestLineLines(["MAC TIME \(timestamp)"])
        case "BYE", "QUIT", "LOGOFF", "HANGUP":
            sendLine("DISCONNECTING.")
            disconnectRemote(sendNoCarrier: true)
        default:
            if uppercasedCommand.hasPrefix("ECHO ") {
                let echoText = String(trimmedCommand.dropFirst(5))
                sendTestLineLines([echoText])
            } else {
                sendTestLineLines(["YOU TYPED: \(trimmedCommand)"])
            }
        }
    }

    private func sendTestLinePrompt() {
        sendSerialData(Array(">".utf8))
    }

    private func sendTestLineLines(_ lines: [String]) {
        for line in lines {
            sendLine(line)
        }
        sendTestLinePrompt()
    }

    private func bytesForSerial(fromRemoteBytes bytes: [UInt8]) -> [UInt8] {
        guard configuration.transportMode == .telnet else {
            return bytes
        }

        var output: [UInt8] = []

        for byte in bytes {
            if waitingForTelnetOption {
                if let command = waitingForTelnetCommand {
                    sendTelnetRefusal(command: command, option: byte)
                }
                waitingForTelnetOption = false
                waitingForTelnetCommand = nil
                continue
            }

            if byte == Self.telnetIAC {
                waitingForTelnetCommand = Self.telnetIAC
                continue
            }

            if let command = waitingForTelnetCommand {
                if command == Self.telnetIAC {
                    switch byte {
                    case Self.telnetIAC:
                        output.append(byte)
                        waitingForTelnetCommand = nil
                    case Self.telnetWILL, Self.telnetWONT, Self.telnetDO, Self.telnetDONT:
                        waitingForTelnetCommand = byte
                        waitingForTelnetOption = true
                    default:
                        waitingForTelnetCommand = nil
                    }
                }
                continue
            }

            output.append(byte)
        }

        return output
    }

    private func sendTelnetRefusal(command: UInt8, option: UInt8) {
        let responseCommand: UInt8
        switch command {
        case Self.telnetDO:
            responseCommand = Self.telnetWONT
        case Self.telnetWILL:
            responseCommand = Self.telnetDONT
        default:
            return
        }

        remoteConnection?.send(content: Data([Self.telnetIAC, responseCommand, option]),
                               completion: .contentProcessed { _ in })
    }

    private func publishCurrentStatus(message: String? = nil) {
        let state: NetworkModemRuntimeState
        if (remoteConnection != nil || activeTestLine),
           carrierDetect {
            state = .connected
        } else if pendingIncomingConnection != nil {
            state = .ringing
        } else if serialConnection == nil {
            state = .waitingForMachine
        } else {
            state = .ready
        }

        statusHandler?(NetworkModemRuntimeStatus(state: state,
                                                 localPort: localPort,
                                                 incomingPort: configuration.acceptsIncomingCalls
                                                 ? configuration.incomingPort
                                                 : nil,
                                                 remoteDescription: remoteDescription,
                                                 message: message))
    }

    private func publishError(_ message: String) {
        statusHandler?(NetworkModemRuntimeStatus(state: .error,
                                                 localPort: localPort,
                                                 incomingPort: configuration.acceptsIncomingCalls
                                                 ? configuration.incomingPort
                                                 : nil,
                                                 remoteDescription: nil,
                                                 message: message))
    }

    private func endpointDescription(_ endpoint: NWEndpoint) -> String {
        switch endpoint {
        case let .hostPort(host, port):
            return "\(host):\(port.rawValue)"
        default:
            return "\(endpoint)"
        }
    }
}

/// Streams Q-Link protocol bytes exchanged with the remote host into two files:
/// a human-readable text log and a raw binary capture. The log reassembles
/// Q-Link frames ($5A … $0D) across chunk boundaries and writes one line per
/// frame (or per raw/handshake chunk) with an absolute millisecond timestamp and
/// the delta from the previous line. The `.cap` file preserves raw bytes by
/// direction as repeated records: dir byte, uint16 little-endian length, payload.
///
/// Frame layout: $5A c1 c2 c3 c4 sendseq recvseq cmd [payload…] $0D
///   c1..c4 = CRC-16 ($A001) nibble-packed; $20 = ACTION (2-char code at payload[0..2]).
///
/// All methods are expected to run on the owning HayesModemService serial queue.
final class QLinkProtocolCapture {
    private let logHandle: FileHandle?
    private let capHandle: FileHandle
    private var bufC2S = [UInt8]()
    private var bufS2C = [UInt8]()
    private var lastLineTime: Date?
    let logURL: URL
    let capURL: URL

    private static let CMD_START: UInt8 = 0x5A
    private static let FRAME_END: UInt8 = 0x0D
    private static let CMD_ACTION: UInt8 = 0x20
    private static let cmdNames: [UInt8: String] = [
        0x20: "ACTION", 0x69: "PING", 0x72: "RESET", 0x73: "RESETACK",
        0x71: "WINDOWFULL", 0x65: "SEQERR", 0x61: "ACK"]

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func capURL(forLogURL logURL: URL) -> URL {
        logURL.deletingPathExtension().appendingPathExtension("cap")
    }

    init?(logURL: URL) {
        let capURL = Self.capURL(forLogURL: logURL)
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        FileManager.default.createFile(atPath: capURL.path, contents: nil)
        guard let logHandle = try? FileHandle(forWritingTo: logURL) else {
            return nil
        }
        guard let capHandle = try? FileHandle(forWritingTo: capURL) else {
            try? logHandle.close()
            return nil
        }
        self.logHandle = logHandle
        self.capHandle = capHandle
        self.logURL = logURL
        self.capURL = capURL
        writeLine("# Q-Link protocol capture — started \(Self.timeFormatter.string(from: Date()))")
        writeLine("# columns: <time> <Δsec> <dir> <frame>   (→ client→server, ← server→client)")
        writeLine("# raw capture: \(capURL.path)")
        writeLine("# raw format: repeated records: dir uint8 (0=C2S,1=S2C), length uint16-le, bytes")
    }

    func close() {
        try? logHandle?.close()
        try? capHandle.close()
    }

    /// direction: 0 = client→server (→), 1 = server→client (←).
    func record(direction: UInt8, bytes: [UInt8]) {
        guard !bytes.isEmpty else {
            return
        }
        writeRawCapture(direction: direction, bytes: bytes)
        if direction == 0 {
            bufC2S.append(contentsOf: bytes)
            drain(&bufC2S, arrow: "→", tag: "C2S")
        } else {
            bufS2C.append(contentsOf: bytes)
            drain(&bufS2C, arrow: "←", tag: "S2C")
        }
    }

    private func drain(_ buf: inout [UInt8], arrow: String, tag: String) {
        while true {
            guard let start = buf.firstIndex(of: Self.CMD_START) else {
                if !buf.isEmpty {
                    emitRaw(Array(buf), arrow: arrow, tag: tag)
                    buf.removeAll()
                }
                return
            }

            if start > 0 {
                emitRaw(Array(buf[0..<start]), arrow: arrow, tag: tag)
                buf.removeFirst(start)
            }

            guard let end = buf[1...].firstIndex(of: Self.FRAME_END) else {
                return  // incomplete frame — wait for more bytes
            }

            let frame = Array(buf[0...end])
            buf.removeFirst(end + 1)
            emitFrame(frame, arrow: arrow, tag: tag)
        }
    }

    private func emitFrame(_ frame: [UInt8], arrow: String, tag: String) {
        guard frame.count >= 9 else {
            emitRaw(frame, arrow: arrow, tag: tag)
            return
        }

        let c1 = frame[1], c2 = frame[2], c3 = frame[3], c4 = frame[4]
        let reportedCRC = (UInt16(c1 & 0xF0 | c2 & 0x0F) << 8) | UInt16(c3 & 0xF0 | c4 & 0x0F)
        let sendSeq = frame[5], recvSeq = frame[6], cmd = frame[7]
        let payload = Array(frame[8..<(frame.count - 1)])
        let computedCRC = Self.crc16(frame[5..<(frame.count - 1)])
        let name = Self.cmdNames[cmd] ?? String(format: "$%02X", cmd)
        let crcMark = computedCRC == reportedCRC
            ? "crc✓"
            : String(format: "crc✗(calc=$%04X)", computedCRC)

        var summary: String
        if cmd == Self.CMD_ACTION, payload.count >= 2 {
            let code = Self.printable(Array(payload[0..<2]))
            summary = "'\(code)' \(Self.printable(Array(payload[2...])))"
        } else {
            summary = Self.printable(payload)
        }

        emit("\(tag) \(arrow) \(name) s\(Self.hex2(sendSeq))/r\(Self.hex2(recvSeq)) \(crcMark) len=\(payload.count)  \(summary)")
    }

    private func emitRaw(_ bytes: [UInt8], arrow: String, tag: String) {
        emit("\(tag) \(arrow) raw \(bytes.count)B  \(Self.escaped(bytes))")
    }

    private func emit(_ body: String) {
        let now = Date()
        let delta = lastLineTime.map { now.timeIntervalSince($0) } ?? 0
        lastLineTime = now
        let deltaText = String(format: "%+8.3f", delta)
        writeLine("\(Self.timeFormatter.string(from: now))  \(deltaText)  \(body)")
    }

    private func writeLine(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else {
            return
        }
        try? logHandle?.write(contentsOf: data)
    }

    private func writeRawCapture(direction: UInt8, bytes: [UInt8]) {
        var offset = bytes.startIndex
        while offset < bytes.endIndex {
            let remaining = bytes.distance(from: offset, to: bytes.endIndex)
            let count = min(remaining, Int(UInt16.max))
            let end = bytes.index(offset, offsetBy: count)
            let length = UInt16(count)
            var record = Data()
            record.append(direction == 1 ? 1 : 0)
            record.append(UInt8(length & 0x00FF))
            record.append(UInt8((length >> 8) & 0x00FF))
            record.append(contentsOf: bytes[offset..<end])
            try? capHandle.write(contentsOf: record)
            offset = end
        }
    }

    private static func crc16(_ bytes: ArraySlice<UInt8>) -> UInt16 {
        var crc: UInt16 = 0
        for byte in bytes {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : (crc >> 1)
            }
        }
        return crc
    }

    private static func hex2(_ byte: UInt8) -> String {
        String(format: "%02X", byte)
    }

    /// Printable rendering for frame payloads: printable ASCII verbatim, others as '.'.
    private static func printable(_ bytes: [UInt8]) -> String {
        String(bytes.map { (32..<127).contains($0) ? Character(UnicodeScalar($0)) : "." })
    }

    /// One-line rendering for raw/handshake bytes: printable ASCII verbatim, common
    /// control chars as escapes, everything else as \xHH so the line stays readable.
    private static func escaped(_ bytes: [UInt8]) -> String {
        var out = ""
        for byte in bytes {
            switch byte {
            case 0x0D: out += "\\r"
            case 0x0A: out += "\\n"
            case 0x09: out += "\\t"
            case 0x20..<0x7F: out.unicodeScalars.append(UnicodeScalar(byte))
            default: out += String(format: "\\x%02X", byte)
            }
        }
        return out
    }
}
