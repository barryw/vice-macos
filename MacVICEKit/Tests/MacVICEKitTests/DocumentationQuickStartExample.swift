// BEGIN: MacVICEKitQuickStart
import SwiftUI
import MacVICEKit

struct EmulatorView: View {
    @State private var session = MacVICEEngineSession(
        configuration: MacVICEMachineConfiguration(
            machine: .c64sc,
            runtimeLocation: .automatic
        )
    )
    @State private var didStart = false

    var body: some View {
        MacVICEDisplayView(session: session)
            .frame(minWidth: 768, minHeight: 544)
            .task {
                guard !didStart else {
                    return
                }
                didStart = true

                do {
                    try session.start()
                } catch {
                    assertionFailure(error.localizedDescription)
                    return
                }

                session.typeText("10 PRINT \"HELLO FROM MACVICEKIT\"\n20 GOTO 10\nRUN\n")
            }
    }
}
// END: MacVICEKitQuickStart
