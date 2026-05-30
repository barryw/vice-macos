import Foundation

extension EmulatorSession {
    func peekMemory(space: MemorySpace = .computer,
                    bank: Int32 = EmulatorSession.currentMemoryBank,
                    address: UInt16,
                    length: Int = 1) -> Data? {
        guard ViceEngineIsRunning(),
              length > 0,
              length <= Int(UInt16.max) + 1 - Int(address) else {
            return nil
        }

        var bytes = [UInt8](repeating: 0, count: length)
        let didPeek = bytes.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return false
            }

            return ViceEnginePeekMemory(space.rawValue,
                                        bank,
                                        UInt32(address),
                                        baseAddress,
                                        UInt32(length))
        }

        return didPeek ? Data(bytes) : nil
    }

    func peekByte(space: MemorySpace = .computer,
                  bank: Int32 = EmulatorSession.currentMemoryBank,
                  address: UInt16) -> UInt8? {
        peekMemory(space: space, bank: bank, address: address, length: 1)?.first
    }

    @discardableResult
    func pokeMemory(space: MemorySpace = .computer,
                    bank: Int32 = EmulatorSession.currentMemoryBank,
                    address: UInt16,
                    bytes: [UInt8]) -> Bool {
        guard ViceEngineIsRunning(),
              !bytes.isEmpty,
              bytes.count <= Int(UInt16.max) + 1 - Int(address) else {
            return false
        }

        return bytes.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return false
            }

            return ViceEnginePokeMemory(space.rawValue,
                                        bank,
                                        UInt32(address),
                                        baseAddress,
                                        UInt32(bytes.count))
        }
    }

    @discardableResult
    func pokeByte(space: MemorySpace = .computer,
                  bank: Int32 = EmulatorSession.currentMemoryBank,
                  address: UInt16,
                  byte: UInt8) -> Bool {
        pokeMemory(space: space, bank: bank, address: address, bytes: [byte])
    }
}
