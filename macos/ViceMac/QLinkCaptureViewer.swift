// QLinkCaptureViewer.swift
//
// Live viewer for Q-Link protocol captures written by the rs232net.c capture
// tap (the "QLinkCaptureFile" resource). The capture is a single interleaved
// file of per-byte records:  <dir:u8><len:u16 LE><payload>  (dir 0 = client→
// server, 1 = server→client). This view tails the file and renders the two
// directions in the order they happened, decoding the Q-Link framing:
//   $5A  CRC×4(nibble-packed, poly $A001)  sendseq recvseq  cmd  payload  $0D
//   cmd $20 = ACTION; ACTION payload[0..2] = 2-char ASCII action code.
//
// Self-contained: depends only on SwiftUI/Foundation + a file path.

import SwiftUI
import Foundation

// MARK: - Decode

enum QLinkDir { case c2s, s2c }

struct QLinkEntry: Identifiable {
    let id = UUID()
    let dir: QLinkDir
    let kind: String          // "HANDSHAKE", "ACTION", "PING", "$xx", ...
    let detail: String        // action code / decoded summary
    let crcOK: Bool?
    let hex: String
    let ascii: String
}

enum QLinkDecoder {
    static let CMD_START: UInt8 = 0x5A
    static let FRAME_END: UInt8 = 0x0D
    static let CMD_ACTION: UInt8 = 0x20
    static let cmdNames: [UInt8: String] = [
        0x20: "ACTION", 0x69: "PING", 0x72: "RESET",
        0x73: "RESETACK", 0x71: "WINDOWFULL", 0x65: "SEQERR", 0x61: "ACK"]

    static func crc16(_ bytes: ArraySlice<UInt8>) -> UInt16 {
        var crc: UInt16 = 0
        for b in bytes {
            crc ^= UInt16(b)
            for _ in 0..<8 { crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : (crc >> 1) }
        }
        return crc
    }

    static func ascii(_ b: ArraySlice<UInt8>) -> String {
        String(b.map { (32..<127).contains($0) ? Character(UnicodeScalar($0)) : "." })
    }
    static func hex(_ b: ArraySlice<UInt8>) -> String {
        b.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    /// Parse the interleaved capture into ordered entries.
    static func parse(_ data: Data) -> [QLinkEntry] {
        let bytes = [UInt8](data)
        var i = 0
        var bufC2S = [UInt8](), bufS2C = [UInt8]()
        var out = [QLinkEntry]()

        func flushHandshake(_ buf: inout [UInt8], _ dir: QLinkDir) {
            // emit leading non-frame bytes (Telenet text) as a HANDSHAKE entry
            guard let start = buf.firstIndex(of: CMD_START) else {
                if !buf.isEmpty {
                    out.append(QLinkEntry(dir: dir, kind: "HANDSHAKE",
                        detail: ascii(buf[...]), crcOK: nil,
                        hex: hex(buf[...]), ascii: ascii(buf[...])))
                    buf.removeAll()
                }
                return
            }
            if start > 0 {
                let h = buf[0..<start]
                out.append(QLinkEntry(dir: dir, kind: "HANDSHAKE",
                    detail: ascii(h), crcOK: nil, hex: hex(h), ascii: ascii(h)))
                buf.removeFirst(start)
            }
        }

        func drainFrames(_ buf: inout [UInt8], _ dir: QLinkDir) {
            flushHandshake(&buf, dir)
            while let s = buf.firstIndex(of: CMD_START),
                  let e = buf[(s+1)...].firstIndex(of: FRAME_END) {
                let frame = Array(buf[s...e])
                buf.removeFirst(e + 1)
                guard frame.count >= 9 else { continue }
                let c1 = frame[1], c2 = frame[2], c3 = frame[3], c4 = frame[4]
                let repCRC = (UInt16(c1 & 0xF0 | c2 & 0x0F) << 8) | UInt16(c3 & 0xF0 | c4 & 0x0F)
                let cmd = frame[7]
                let payload = frame[8..<(frame.count - 1)]
                let calc = crc16(frame[5..<(frame.count - 1)])
                let name = cmdNames[cmd] ?? String(format: "$%02X", cmd)
                var detail = ""
                if cmd == CMD_ACTION, payload.count >= 2 {
                    let code = ascii(payload[payload.startIndex..<payload.startIndex+2])
                    detail = "'\(code)' " + ascii(payload[(payload.startIndex+2)...])
                } else {
                    detail = ascii(payload)
                }
                out.append(QLinkEntry(dir: dir, kind: name, detail: detail,
                    crcOK: calc == repCRC, hex: hex(payload), ascii: ascii(payload)))
                flushHandshake(&buf, dir)
            }
        }

        while i + 3 <= bytes.count {
            let dir = bytes[i]; let n = Int(bytes[i+1]) | (Int(bytes[i+2]) << 8); i += 3
            guard i + n <= bytes.count else { break }
            if dir == 1 { bufS2C.append(contentsOf: bytes[i..<i+n]) }
            else { bufC2S.append(contentsOf: bytes[i..<i+n]) }
            i += n
            drainFrames(&bufC2S, .c2s)
            drainFrames(&bufS2C, .s2c)
        }
        return out
    }
}

// MARK: - Model (tails the file)

@MainActor
final class QLinkCaptureViewerModel: ObservableObject {
    @Published var entries: [QLinkEntry] = []
    @Published var path: String = ""
    private var timer: Timer?

    func start(path: String) {
        self.path = path
        timer?.invalidate()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func refresh() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return }
        entries = QLinkDecoder.parse(data)
    }
}

// MARK: - View

struct QLinkCaptureViewer: View {
    @StateObject private var model = QLinkCaptureViewerModel()
    let capturePath: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Q-Link Packet Capture").font(.headline)
                Spacer()
                Text("\(model.entries.count) frames").foregroundStyle(.secondary)
                Button("Done") { dismiss() }
            }.padding()
            Divider()
            ScrollViewReader { proxy in
                List(model.entries) { e in
                    QLinkEntryRow(entry: e).id(e.id)
                }
                .onChange(of: model.entries.count) { _, _ in
                    if let last = model.entries.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 420)
        .onAppear { model.start(path: capturePath) }
        .onDisappear { model.stop() }
    }
}

private struct QLinkEntryRow: View {
    let entry: QLinkEntry

    private var arrow: String { entry.dir == .c2s ? "→" : "←" }
    private var arrowColor: Color { entry.dir == .c2s ? .blue : .green }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(arrow).foregroundStyle(arrowColor).bold()
            VStack(alignment: .leading, spacing: 2) {
                header
                Text(entry.hex)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(entry.kind).bold()
            if let ok = entry.crcOK {
                Text(ok ? "crc✓" : "crc✗")
                    .font(.caption)
                    .foregroundStyle(ok ? Color.secondary : Color.red)
            }
            Text(entry.detail).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}
