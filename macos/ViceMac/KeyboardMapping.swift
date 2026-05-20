import AppKit

struct PressedEmulatorKey {
    let symbol: Int64
    let modifiers: Int32
}

struct EmulatorModifierKey {
    let symbol: Int64
    let modifiers: Int32
    let isToggle: Bool
}

enum ViceMacKeyMapper {
    private enum Modifier {
        static let leftShift: Int32 = 1 << 0
        static let rightShift: Int32 = 1 << 1
        static let leftControl: Int32 = 1 << 2
        static let leftOption: Int32 = 1 << 4
        static let rightOption: Int32 = 1 << 5
    }

    private enum Key {
        static let backspace: Int64 = 0xff08
        static let tab: Int64 = 0xff09
        static let returnKey: Int64 = 0xff0d
        static let escape: Int64 = 0xff1b
        static let insert: Int64 = 0xff63
        static let delete: Int64 = 0xffff
        static let home: Int64 = 0xff50
        static let left: Int64 = 0xff51
        static let up: Int64 = 0xff52
        static let right: Int64 = 0xff53
        static let down: Int64 = 0xff54
        static let pageUp: Int64 = 0xff55
        static let pageDown: Int64 = 0xff56
        static let end: Int64 = 0xff57
        static let shiftLeft: Int64 = 0xffe1
        static let shiftRight: Int64 = 0xffe2
        static let controlLeft: Int64 = 0xffe3
        static let capsLock: Int64 = 0xffe5
        static let f1: Int64 = 0xffbe
    }

    private enum MacKeyCode {
        static let tab: UInt16 = 48
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let escape: UInt16 = 53
        static let delete: UInt16 = 51
        static let forwardDelete: UInt16 = 117
        static let home: UInt16 = 115
        static let end: UInt16 = 119
        static let pageUp: UInt16 = 116
        static let pageDown: UInt16 = 121
        static let leftArrow: UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let downArrow: UInt16 = 125
        static let upArrow: UInt16 = 126
        static let leftShift: UInt16 = 56
        static let rightShift: UInt16 = 60
        static let capsLock: UInt16 = 57
        static let leftControl: UInt16 = 59
        static let f1: UInt16 = 122
        static let f2: UInt16 = 120
        static let f3: UInt16 = 99
        static let f4: UInt16 = 118
        static let f5: UInt16 = 96
        static let f6: UInt16 = 97
        static let f7: UInt16 = 98
        static let f8: UInt16 = 100
        static let f9: UInt16 = 101
        static let f10: UInt16 = 109
        static let f11: UInt16 = 103
        static let f12: UInt16 = 111
    }

    static func symbol(for event: NSEvent) -> Int64? {
        if let special = specialSymbol(for: event.keyCode) {
            return special
        }

        guard let scalar = event.characters?.unicodeScalars.first,
              scalar.value >= 0x20,
              scalar.value <= 0x7e else {
            return nil
        }

        return Int64(scalar.value)
    }

    static func modifiers(for event: NSEvent) -> Int32 {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: Int32 = 0

        if flags.contains(.shift) {
            modifiers |= Modifier.leftShift
        }
        if flags.contains(.control) {
            modifiers |= Modifier.leftControl
        }
        if flags.contains(.option) {
            modifiers |= Modifier.leftOption
        }

        return modifiers
    }

    static func modifierKey(for event: NSEvent) -> EmulatorModifierKey? {
        switch event.keyCode {
        case MacKeyCode.leftShift:
            return EmulatorModifierKey(symbol: Key.shiftLeft,
                                       modifiers: Modifier.leftShift,
                                       isToggle: false)
        case MacKeyCode.rightShift:
            return EmulatorModifierKey(symbol: Key.shiftRight,
                                       modifiers: Modifier.rightShift,
                                       isToggle: false)
        case MacKeyCode.leftControl:
            return EmulatorModifierKey(symbol: Key.controlLeft,
                                       modifiers: Modifier.leftControl,
                                       isToggle: false)
        case MacKeyCode.capsLock:
            return EmulatorModifierKey(symbol: Key.capsLock,
                                       modifiers: 0,
                                       isToggle: true)
        default:
            return nil
        }
    }

    private static func specialSymbol(for keyCode: UInt16) -> Int64? {
        switch keyCode {
        case MacKeyCode.tab:
            return Key.tab
        case MacKeyCode.returnKey, MacKeyCode.keypadEnter:
            return Key.returnKey
        case MacKeyCode.escape:
            return Key.escape
        case MacKeyCode.delete:
            return Key.backspace
        case MacKeyCode.forwardDelete:
            return Key.delete
        case MacKeyCode.home:
            return Key.home
        case MacKeyCode.end:
            return Key.end
        case MacKeyCode.pageUp:
            return Key.pageUp
        case MacKeyCode.pageDown:
            return Key.pageDown
        case MacKeyCode.leftArrow:
            return Key.left
        case MacKeyCode.rightArrow:
            return Key.right
        case MacKeyCode.downArrow:
            return Key.down
        case MacKeyCode.upArrow:
            return Key.up
        default:
            return functionSymbol(for: keyCode)
        }
    }

    private static func functionSymbol(for keyCode: UInt16) -> Int64? {
        switch keyCode {
        case MacKeyCode.f1:
            return Key.f1
        case MacKeyCode.f2:
            return Key.f1 + 1
        case MacKeyCode.f3:
            return Key.f1 + 2
        case MacKeyCode.f4:
            return Key.f1 + 3
        case MacKeyCode.f5:
            return Key.f1 + 4
        case MacKeyCode.f6:
            return Key.f1 + 5
        case MacKeyCode.f7:
            return Key.f1 + 6
        case MacKeyCode.f8:
            return Key.f1 + 7
        case MacKeyCode.f9:
            return Key.f1 + 8
        case MacKeyCode.f10:
            return Key.f1 + 9
        case MacKeyCode.f11:
            return Key.f1 + 10
        case MacKeyCode.f12:
            return Key.f1 + 11
        default:
            return nil
        }
    }
}
