import Foundation

enum ViceResource {
    static let speed = "Speed"
    static let sidModel = "SidModel"
    static let sound = "Sound"
    static let soundVolume = "SoundVolume"
    static let reu = "REU"
    static let reuSize = "REUsize"
    static let georam = "GEORAM"
    static let georamSize = "GEORAMsize"
    static let ramCart = "RAMCART"
    static let ramCartSize = "RAMCARTsize"
    static let dqbb = "DQBB"
    static let dqbbSize = "DQBBSize"
    static let dqbbMode = "DQBBMode"
    static let isepicCartridgeEnabled = "IsepicCartridgeEnabled"
    static let isepicSwitch = "IsepicSwitch"
    static let memoryHack = "MemoryHack"
    static let c64_256kBase = "C64_256Kbase"
    static let plus60kBase = "PLUS60Kbase"
    static let vic20RAMBlocks: [(block: Int, name: String)] = [
        (0, "RAMBlock0"),
        (1, "RAMBlock1"),
        (2, "RAMBlock2"),
        (3, "RAMBlock3"),
        (5, "RAMBlock5")
    ]
}

enum ViceDQBBMode {
    static let c64: Int32 = 1
}
