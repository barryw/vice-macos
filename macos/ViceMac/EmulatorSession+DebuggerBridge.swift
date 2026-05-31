import Foundation
import MacVICEKit

extension EmulatorSession {
    func peekMemory(space: MemorySpace = .computer,
                    bank: Int32 = EmulatorSession.currentMemoryBank,
                    address: UInt16,
                    length: Int = 1) -> Data? {
        guard engine.isRunning,
              length > 0,
              length <= Int(UInt16.max) + 1 - Int(address) else {
            return nil
        }

        guard let memorySpace = MacVICEMemorySpace(rawValue: space.rawValue) else {
            return nil
        }

        return try? engine.debugger.peek(memorySpace: memorySpace,
                                         bank: bank,
                                         address: UInt32(address),
                                         length: length)
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
        guard engine.isRunning,
              !bytes.isEmpty,
              bytes.count <= Int(UInt16.max) + 1 - Int(address) else {
            return false
        }

        guard let memorySpace = MacVICEMemorySpace(rawValue: space.rawValue) else {
            return false
        }

        do {
            try engine.debugger.poke(memorySpace: memorySpace,
                                     bank: bank,
                                     address: UInt32(address),
                                     bytes: Data(bytes))
            return true
        } catch {
            return false
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
