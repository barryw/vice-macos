import Foundation

enum RAMExpansion: String, CaseIterable, Identifiable {
    case none
    case vic20_3k
    case vic20_8kBlock1
    case vic20_8kBlock2
    case vic20_8kBlock3
    case vic20_8kBlock5
    case vic20_11k
    case vic20_16k
    case vic20_19k
    case vic20_24k
    case vic20_27k
    case vic20_32k
    case vic20_35k
    case reu128
    case reu256
    case reu512
    case reu1024
    case reu2048
    case reu4096
    case reu8192
    case reu16384
    case georam512
    case georam1024
    case georam2048
    case georam4096
    case ramcart64
    case ramcart128
    case dqbb16
    case dqbb32
    case dqbb64
    case dqbb128
    case dqbb256
    case isepic
    case c64_256kDE00
    case c64_256kDE80
    case c64_256kDF00
    case c64_256kDF80
    case plus60kD040
    case plus60kD100
    case plus256k

    var id: String { rawValue }

    static let c64Options: [RAMExpansion] = [
        .none,
        .reu128,
        .reu256,
        .reu512,
        .reu1024,
        .reu2048,
        .reu4096,
        .reu8192,
        .reu16384,
        .georam512,
        .georam1024,
        .georam2048,
        .georam4096,
        .ramcart64,
        .ramcart128,
        .dqbb16,
        .dqbb32,
        .dqbb64,
        .dqbb128,
        .dqbb256,
        .isepic,
        .c64_256kDE00,
        .c64_256kDE80,
        .c64_256kDF00,
        .c64_256kDF80,
        .plus60kD040,
        .plus60kD100,
        .plus256k
    ]

    static let c128Options: [RAMExpansion] = [
        .none,
        .reu128,
        .reu256,
        .reu512,
        .reu1024,
        .reu2048,
        .reu4096,
        .reu8192,
        .reu16384,
        .georam512,
        .georam1024,
        .georam2048,
        .georam4096,
        .ramcart64,
        .ramcart128,
        .dqbb16,
        .dqbb32,
        .dqbb64,
        .dqbb128,
        .dqbb256,
        .isepic
    ]

    static let vic20Options: [RAMExpansion] = [
        .none,
        .vic20_3k,
        .vic20_8kBlock1,
        .vic20_8kBlock2,
        .vic20_8kBlock3,
        .vic20_8kBlock5,
        .vic20_11k,
        .vic20_16k,
        .vic20_19k,
        .vic20_24k,
        .vic20_27k,
        .vic20_32k,
        .vic20_35k
    ]

    var title: String {
        switch self {
        case .none:
            return "None"
        case .vic20_3k:
            return "VIC-20 3K"
        case .vic20_8kBlock1:
            return "VIC-20 8K BLK1"
        case .vic20_8kBlock2:
            return "VIC-20 8K BLK2"
        case .vic20_8kBlock3:
            return "VIC-20 8K BLK3"
        case .vic20_8kBlock5:
            return "VIC-20 8K BLK5"
        case .vic20_11k:
            return "VIC-20 11K"
        case .vic20_16k:
            return "VIC-20 16K"
        case .vic20_19k:
            return "VIC-20 19K"
        case .vic20_24k:
            return "VIC-20 24K"
        case .vic20_27k:
            return "VIC-20 27K"
        case .vic20_32k:
            return "VIC-20 32K"
        case .vic20_35k:
            return "VIC-20 35K"
        case .reu128, .reu256, .reu512, .reu1024, .reu2048, .reu4096, .reu8192, .reu16384:
            return "REU \(sizeTitle)"
        case .georam512, .georam1024, .georam2048, .georam4096:
            return "GeoRAM \(sizeTitle)"
        case .ramcart64, .ramcart128:
            return "RamCart \(sizeTitle)"
        case .dqbb16, .dqbb32, .dqbb64, .dqbb128, .dqbb256:
            return "DQBB \(sizeTitle)"
        case .isepic:
            return "ISEPIC 2K"
        case .c64_256kDE00:
            return "C64 256K @ $DE00"
        case .c64_256kDE80:
            return "C64 256K @ $DE80"
        case .c64_256kDF00:
            return "C64 256K @ $DF00"
        case .c64_256kDF80:
            return "C64 256K @ $DF80"
        case .plus60kD040:
            return "+60K @ $D040"
        case .plus60kD100:
            return "+60K @ $D100"
        case .plus256k:
            return "+256K"
        }
    }

    var statusTitle: String {
        self == .none ? "disabled" : title
    }

    func displayTitle(for machine: EmulatedMachine) -> String {
        guard machine.usesVIC20MemoryExpansion else {
            return title
        }

        switch self {
        case .none:
            return "VIC-20 5K (unexpanded)"
        case .vic20_3k:
            return "VIC-20 3K (BLK0)"
        case .vic20_8kBlock1:
            return "VIC-20 8K (BLK1)"
        case .vic20_8kBlock2:
            return "VIC-20 8K (BLK2)"
        case .vic20_8kBlock3:
            return "VIC-20 8K (BLK3)"
        case .vic20_8kBlock5:
            return "VIC-20 8K (BLK5)"
        case .vic20_11k:
            return "VIC-20 11K (BLK0 + BLK1)"
        case .vic20_16k:
            return "VIC-20 16K (BLK1 + BLK2)"
        case .vic20_19k:
            return "VIC-20 19K (BLK0 + BLK1 + BLK2)"
        case .vic20_24k:
            return "VIC-20 24K (BASIC max)"
        case .vic20_27k:
            return "VIC-20 27K (24K BASIC + BLK0)"
        case .vic20_32k:
            return "VIC-20 32K (24K BASIC + BLK5)"
        case .vic20_35k:
            return "VIC-20 35K (24K BASIC + BLK0 + BLK5)"
        default:
            return title
        }
    }

    var chipTitle: String {
        switch self {
        case .none:
            return ""
        case .vic20_3k:
            return "3K"
        case .vic20_8kBlock1:
            return "8K B1"
        case .vic20_8kBlock2:
            return "8K B2"
        case .vic20_8kBlock3:
            return "8K B3"
        case .vic20_8kBlock5:
            return "8K B5"
        case .vic20_11k:
            return "11K"
        case .vic20_16k:
            return "16K"
        case .vic20_19k:
            return "19K"
        case .vic20_24k:
            return "24K"
        case .vic20_27k:
            return "27K"
        case .vic20_32k:
            return "32K"
        case .vic20_35k:
            return "35K"
        case .c64_256kDE00, .c64_256kDE80, .c64_256kDF00, .c64_256kDF80:
            return "C64 256K"
        case .plus60kD040, .plus60kD100:
            return "+60K"
        default:
            return title
        }
    }

    fileprivate var device: RAMExpansionDevice {
        switch self {
        case .none:
            return .none
        case .vic20_3k, .vic20_8kBlock1, .vic20_8kBlock2, .vic20_8kBlock3, .vic20_8kBlock5,
             .vic20_11k, .vic20_16k, .vic20_19k, .vic20_24k, .vic20_27k, .vic20_32k,
             .vic20_35k:
            return .vic20Blocks
        case .reu128, .reu256, .reu512, .reu1024, .reu2048, .reu4096, .reu8192, .reu16384:
            return .reu
        case .georam512, .georam1024, .georam2048, .georam4096:
            return .georam
        case .ramcart64, .ramcart128:
            return .ramcart
        case .dqbb16, .dqbb32, .dqbb64, .dqbb128, .dqbb256:
            return .dqbb
        case .isepic:
            return .isepic
        case .c64_256kDE00, .c64_256kDE80, .c64_256kDF00, .c64_256kDF80,
             .plus60kD040, .plus60kD100, .plus256k:
            return .memoryHack
        }
    }

    fileprivate var sizeKiB: Int32? {
        switch self {
        case .reu128, .dqbb128, .ramcart128:
            return 128
        case .reu256, .dqbb256:
            return 256
        case .reu512, .georam512:
            return 512
        case .reu1024, .georam1024:
            return 1024
        case .reu2048, .georam2048:
            return 2048
        case .reu4096, .georam4096:
            return 4096
        case .reu8192:
            return 8192
        case .reu16384:
            return 16384
        case .ramcart64, .dqbb64:
            return 64
        case .dqbb16:
            return 16
        case .dqbb32:
            return 32
        case .none, .isepic, .c64_256kDE00, .c64_256kDE80, .c64_256kDF00, .c64_256kDF80,
             .plus60kD040, .plus60kD100, .plus256k, .vic20_3k, .vic20_8kBlock1,
             .vic20_8kBlock2, .vic20_8kBlock3, .vic20_8kBlock5, .vic20_11k, .vic20_16k,
             .vic20_19k, .vic20_24k, .vic20_27k, .vic20_32k, .vic20_35k:
            return nil
        }
    }

    fileprivate var memoryHack: Int32 {
        switch self {
        case .c64_256kDE00, .c64_256kDE80, .c64_256kDF00, .c64_256kDF80:
            return 1
        case .plus60kD040, .plus60kD100:
            return 2
        case .plus256k:
            return 3
        case .none, .reu128, .reu256, .reu512, .reu1024, .reu2048, .reu4096, .reu8192, .reu16384,
             .georam512, .georam1024, .georam2048, .georam4096, .ramcart64, .ramcart128,
             .dqbb16, .dqbb32, .dqbb64, .dqbb128, .dqbb256, .isepic, .vic20_3k,
             .vic20_8kBlock1, .vic20_8kBlock2, .vic20_8kBlock3, .vic20_8kBlock5,
             .vic20_11k, .vic20_16k, .vic20_19k, .vic20_24k, .vic20_27k, .vic20_32k,
             .vic20_35k:
            return 0
        }
    }

    fileprivate var baseAddress: Int32? {
        switch self {
        case .c64_256kDE00:
            return 0xde00
        case .c64_256kDE80:
            return 0xde80
        case .c64_256kDF00:
            return 0xdf00
        case .c64_256kDF80:
            return 0xdf80
        case .plus60kD040:
            return 0xd040
        case .plus60kD100:
            return 0xd100
        case .none, .reu128, .reu256, .reu512, .reu1024, .reu2048, .reu4096, .reu8192, .reu16384,
             .georam512, .georam1024, .georam2048, .georam4096, .ramcart64, .ramcart128,
             .dqbb16, .dqbb32, .dqbb64, .dqbb128, .dqbb256, .isepic, .plus256k, .vic20_3k,
             .vic20_8kBlock1, .vic20_8kBlock2, .vic20_8kBlock3, .vic20_8kBlock5,
             .vic20_11k, .vic20_16k, .vic20_19k, .vic20_24k, .vic20_27k, .vic20_32k,
             .vic20_35k:
            return nil
        }
    }

    var detailTitle: String {
        switch self {
        case .none:
            return "Unexpanded"
        case .vic20_3k, .vic20_8kBlock1, .vic20_8kBlock2, .vic20_8kBlock3, .vic20_8kBlock5,
             .vic20_11k, .vic20_16k, .vic20_19k, .vic20_24k, .vic20_27k, .vic20_32k,
             .vic20_35k:
            return vic20BlockTitle
        default:
            return title
        }
    }

    func detailTitle(for machine: EmulatedMachine) -> String {
        guard machine.usesVIC20MemoryExpansion else {
            return detailTitle
        }

        switch self {
        case .vic20_24k:
            return "\(vic20BlockTitle); BASIC shows 28159 bytes free"
        case .vic20_27k, .vic20_32k, .vic20_35k:
            return "\(vic20BlockTitle); BASIC still shows 28159 bytes free"
        default:
            return detailTitle
        }
    }

    var vic20MemorySpec: String? {
        switch self {
        case .none:
            return "none"
        case .vic20_3k:
            return "3k"
        case .vic20_8kBlock1:
            return "8k"
        case .vic20_8kBlock2:
            return "2"
        case .vic20_8kBlock3:
            return "3"
        case .vic20_8kBlock5:
            return "5"
        case .vic20_11k:
            return "3k,8k"
        case .vic20_16k:
            return "16k"
        case .vic20_19k:
            return "3k,16k"
        case .vic20_24k:
            return "24k"
        case .vic20_27k:
            return "3k,24k"
        case .vic20_32k:
            return "1,2,3,5"
        case .vic20_35k:
            return "all"
        default:
            return nil
        }
    }

    fileprivate var vic20RAMBlocks: Set<Int> {
        switch self {
        case .vic20_3k:
            return [0]
        case .vic20_8kBlock1:
            return [1]
        case .vic20_8kBlock2:
            return [2]
        case .vic20_8kBlock3:
            return [3]
        case .vic20_8kBlock5:
            return [5]
        case .vic20_11k:
            return [0, 1]
        case .vic20_16k:
            return [1, 2]
        case .vic20_19k:
            return [0, 1, 2]
        case .vic20_24k:
            return [1, 2, 3]
        case .vic20_27k:
            return [0, 1, 2, 3]
        case .vic20_32k:
            return [1, 2, 3, 5]
        case .vic20_35k:
            return [0, 1, 2, 3, 5]
        default:
            return []
        }
    }

    private var sizeTitle: String {
        guard let sizeKiB else {
            return ""
        }

        if sizeKiB >= 1024 {
            return "\(sizeKiB / 1024)M"
        }

        return "\(sizeKiB)K"
    }

    private var vic20BlockTitle: String {
        let blocks = vic20RAMBlocks.sorted()

        guard !blocks.isEmpty else {
            return "Unexpanded"
        }

        let names = blocks.map { block in
            block == 0 ? "BLK0" : "BLK\(block)"
        }
        return names.joined(separator: " + ")
    }

    func resourcePlan(for machine: EmulatedMachine) -> RAMExpansionResourcePlan {
        RAMExpansionResourcePlan(disableAssignments: Self.disableAssignments(for: machine),
                                 enableAssignments: enableAssignments,
                                 requiresHardReset: machine.usesVIC20MemoryExpansion)
    }

    private static func disableAssignments(for machine: EmulatedMachine) -> [ViceIntResourceAssignment] {
        if machine.usesVIC20MemoryExpansion {
            return vic20BlockAssignments(for: [])
        }

        return [
            ViceIntResourceAssignment(name: ViceResource.reu, value: 0),
            ViceIntResourceAssignment(name: ViceResource.georam, value: 0),
            ViceIntResourceAssignment(name: ViceResource.ramCart, value: 0),
            ViceIntResourceAssignment(name: ViceResource.dqbb, value: 0),
            ViceIntResourceAssignment(name: ViceResource.isepicCartridgeEnabled, value: 0),
            ViceIntResourceAssignment(name: ViceResource.isepicSwitch, value: 0),
            ViceIntResourceAssignment(name: ViceResource.memoryHack, value: 0)
        ]
    }

    private var enableAssignments: [ViceIntResourceAssignment] {
        switch device {
        case .none:
            return []
        case .vic20Blocks:
            return Self.vic20BlockAssignments(for: vic20RAMBlocks)
        case .reu:
            return sizedDeviceAssignments(sizeResource: ViceResource.reuSize,
                                          enableResource: ViceResource.reu)
        case .georam:
            return sizedDeviceAssignments(sizeResource: ViceResource.georamSize,
                                          enableResource: ViceResource.georam)
        case .ramcart:
            return sizedDeviceAssignments(sizeResource: ViceResource.ramCartSize,
                                          enableResource: ViceResource.ramCart)
        case .dqbb:
            var assignments = sizedDeviceAssignments(sizeResource: ViceResource.dqbbSize,
                                                     enableResource: ViceResource.dqbb)
            assignments.insert(ViceIntResourceAssignment(name: ViceResource.dqbbMode,
                                                        value: ViceDQBBMode.c64),
                               at: assignments.isEmpty ? 0 : assignments.count - 1)
            return assignments
        case .isepic:
            return [
                ViceIntResourceAssignment(name: ViceResource.isepicSwitch, value: 1),
                ViceIntResourceAssignment(name: ViceResource.isepicCartridgeEnabled, value: 1)
            ]
        case .memoryHack:
            var assignments: [ViceIntResourceAssignment] = []
            if let baseAddress {
                switch self {
                case .c64_256kDE00, .c64_256kDE80, .c64_256kDF00, .c64_256kDF80:
                    assignments.append(ViceIntResourceAssignment(name: ViceResource.c64_256kBase,
                                                                 value: baseAddress))
                case .plus60kD040, .plus60kD100:
                    assignments.append(ViceIntResourceAssignment(name: ViceResource.plus60kBase,
                                                                 value: baseAddress))
                default:
                    break
                }
            }
            assignments.append(ViceIntResourceAssignment(name: ViceResource.memoryHack,
                                                        value: memoryHack))
            return assignments
        }
    }

    private func sizedDeviceAssignments(sizeResource: String,
                                        enableResource: String) -> [ViceIntResourceAssignment] {
        var assignments: [ViceIntResourceAssignment] = []
        if let sizeKiB {
            assignments.append(ViceIntResourceAssignment(name: sizeResource, value: sizeKiB))
        }
        assignments.append(ViceIntResourceAssignment(name: enableResource, value: 1))
        return assignments
    }

    private static func vic20BlockAssignments(for blocks: Set<Int>) -> [ViceIntResourceAssignment] {
        ViceResource.vic20RAMBlocks.map { resource in
            ViceIntResourceAssignment(name: resource.name,
                                      value: blocks.contains(resource.block) ? 1 : 0)
        }
    }
}

fileprivate enum RAMExpansionDevice {
    case none
    case vic20Blocks
    case reu
    case georam
    case ramcart
    case dqbb
    case isepic
    case memoryHack
}

struct RAMExpansionResourcePlan: Equatable {
    let disableAssignments: [ViceIntResourceAssignment]
    let enableAssignments: [ViceIntResourceAssignment]
    let requiresHardReset: Bool
}
