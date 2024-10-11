import NostrSDK
import SwiftUI

struct RelayManagerView: View {
    @ObservedObject var vm = RelayManagerViewModel()

    var body: some View {
        List {
            Section {
                ForEach(vm.relayList, id: \.self) { relayURL in
                    Text(relayURL)
                }
                .onDelete(perform: { offsets in
                    vm.removeRelay(at: offsets)
                })
                TextField("enter new relay URL", text: $vm.newRelayURLString)
                    .onSubmit { vm.addRelay() }
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
            } footer: {
                Text("Swipe to delete. Changes will be in effect as soon as you restart the app. Relay URLs must have the correct prefix and format.")
            }
        }
        .alertView(isPresented: $vm.showAlert, currentAlert: vm.currentAlert)
    }
}

#Preview {
    RelayManagerView()
}

@MainActor
class RelayManagerViewModel: ObservableObject {
    @Published var relayList = [String]()
    @Published var error: Error?
    @Published var newRelayURLString = ""

    @Published var showAlert: Bool = false
    var currentAlert: AlertDetail?

    init() {
        relayList = NostrService.shared.dataManager.relayURLlist
    }

    func addRelay() {
        // needs to check for uniqueness and URL format

        if !(newRelayURLString.hasPrefix("wss://") || newRelayURLString.hasPrefix("ws://")) {
            displayAlert(alert: AlertDetail(title: "Missing prefix",
                                            description: "URLs for nostr relays are websocket URLs and should start with wss:// or ws://"))
        } else if relayList.contains(newRelayURLString) {
            displayAlert(alert: AlertDetail(title: "Already added.",
                                            description: "This URL is already in the list of relays, please choose another one."))
        } else {
            relayList.append(newRelayURLString)
            NostrService.shared.dataManager.addRelay(with: newRelayURLString)
        }

        newRelayURLString = ""
    }

    func removeRelay(at offsets: IndexSet) {
        displayAlert(alert: AlertDetail(title: "Are you sure?",
                                        description: "Do you really want to remove this nostr Relay?",
                                        primaryButtonText: "Cancel",
                                        affirmText: "Yes",
                                        onAffirm: {
                                            // should not be more than one index
                                            for index in offsets {
                                                NostrService.shared.dataManager.removeRelay(with: self.relayList[index])
                                                self.relayList.remove(atOffsets: offsets)
                                            }
                                        }))
    }

    private func displayAlert(alert: AlertDetail) {
        currentAlert = alert
        showAlert = true
    }
}
