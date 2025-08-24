import SwiftUI
import SwiftData
import Flow
import CashuSwift

struct MintListView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Query private var mints: [Mint]
    
    var mintOfActiveWallet: [Mint] {
        mints.filter { $0.wallet?.active == true }
    }
    
    var body: some View {
        List {
            ForEach(mintOfActiveWallet) { m in
                NavigationLink(destination: ProofListView(mint: m),
                               label: {
                    Text(m.url.absoluteString)
                })
            }
        }
    }
}

#Preview {
    MintListView()
}

struct ProofListView: View {
    let id = UUID()
    
    @Environment(\.modelContext) private var modelContext
    @Query private var allProofs: [Proof]
    
    @State private var remoteStates: [String : CashuSwift.Proof.ProofState]? = nil
        
    var mint:Mint
    
    private var mintProofs: [Proof] {
        allProofs.filter({ $0.mint?.mintID == mint.mintID })
    }
    
    private var sortedProofs: [Proof] {
        let outer = [
            mintProofs.filter({ $0.state == .valid }).sorted(by: { $0.amount < $1.amount }),
            mintProofs.filter({ $0.state == .pending }).sorted(by: { $0.amount < $1.amount }),
            mintProofs.filter({ $0.state == .spent }).sorted(by: { $0.amount < $1.amount })
        ]
        return outer.flatMap { $0 }
    }
    
    init(mint: Mint) {
        self.mint = mint
    }
    
    var body: some View {
        List {
            Section {
                Button {
                    Task {
                        let result = try await CashuSwift.check(mintProofs.sendable(), url: mint.url)
                        await MainActor.run {
                            var dict = [String : CashuSwift.Proof.ProofState]()
                            for (i, p) in mintProofs.enumerated() {
                                dict[p.C] = result[i]
                                print("e: \(p.dleq?.e ?? "") has state: \(p.state) remote is: \(result[i])")
                            }
                            remoteStates = dict
                        }
                    }
                } label: {
                    Text("Load States")
                }
                Button {
                    guard let remoteStates, remoteStates.values.count == sortedProofs.count else {
                        return
                    }
                    for p in mintProofs {
                        if let state = remoteStates[p.C] { p.state = Proof.State(state: state) }
                    }
                } label: {
                    Text("Overwrite ⚠")
                }.disabled(remoteStates == nil)
            }
            Section(content: {
                ForEach(sortedProofs) { proof in
                    NavigationLink {
                        ProofDataView(proof: proof)
                    } label: {
                        HStack {
                            if let remoteStates, let state = remoteStates[proof.C] {
                                Group {
                                    switch state {
                                    case .unspent:
                                        RoundedRectangle(cornerRadius: 2)
                                            .foregroundStyle(.green)
                                            .frame(width: 6)
                                    case .pending:
                                        RoundedRectangle(cornerRadius: 2)
                                            .foregroundStyle(.yellow)
                                            .frame(width: 6)
                                    case .spent:
                                        RoundedRectangle(cornerRadius: 2)
                                            .foregroundStyle(.red)
                                            .frame(width: 6)
                                    }
                                }
                            }
                            VStack(alignment:.leading) {
                                HStack {
                                    switch proof.state {
                                    case .valid:
                                        Circle()
                                            .frame(width: 10)
                                            .foregroundStyle(.green)
                                    case .pending:
                                        Circle()
                                            .frame(width: 10)
                                            .foregroundStyle(.yellow)
                                    case .spent:
                                        Circle()
                                            .frame(width: 10)
                                            .foregroundStyle(.red)
                                    }
                                    Text(proof.C.prefix(10) + "...")
                                    Spacer()
                                    Text(String(proof.amount))
                                }
                                .bold()
                                .font(.title3)
                                .monospaced()
                                HFlow() {
                                    TagView(text: proof.keysetID)
                                    TagView(text: proof.unit.rawValue)
                                    TagView(text: String(proof.inputFeePPK))
                                }
                            }
                        }
                    }
                }
            }, header: {
                Text("\(sortedProofs.count) objects")
            })
        }
        .navigationTitle(mint.url.host(percentEncoded:false) ?? "")
    }
}

extension Proof.State {
    init(state: CashuSwift.Proof.ProofState) {
        switch state {
        case .unspent:
            self = .valid
        case .pending:
            self = .pending
        case .spent:
            self = .spent
        }
    }
}


struct TagView: View {
    var text:String
    var backgroundColor:Color = .secondary.opacity(0.3)
    
    var body: some View {
        Text(text)
            .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            .background(backgroundColor)
            .cornerRadius(4)
    }
}
