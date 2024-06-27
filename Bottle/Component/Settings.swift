//
//  Settings.swift
//  Bottle
//
//  Created by Cobalt Velvet on 2024/5/26.
//

import SwiftUI

struct Settings: View {
    @AppStorage("safeMode") var safeMode = true
    
    @AppStorage("serverAddress") var serverAddress: String = ""
    
    @AppStorage("pandaMemberID") var pandaMemberID: String = ""
    @AppStorage("pandaPassHash") var pandaPassHash: String = ""
    @AppStorage("pandaIgneous") var pandaIgneous: String = ""

    var body: some View {
        Spacer()
        HStack {
            Spacer()
            Form {
                Section(header: Text("General")) {
                    Toggle("Safe Mode", isOn: $safeMode)
                }

                Section(header: Text("Server")) {
                    TextField("Address", text: $serverAddress)
                        .autocorrectionDisabled()

                }

                Section(header: Text("Panda")) {
                    TextField("Member ID", text: $pandaMemberID)
                        .autocorrectionDisabled()
                    TextField("Password Hash", text: $pandaPassHash)
                        .autocorrectionDisabled()
                    TextField("Igneous", text: $pandaIgneous)
                        .autocorrectionDisabled()
                }
            }
            Spacer()
        }
        Spacer()
    }
}

#Preview {
    Settings()
}
