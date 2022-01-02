//
//  ContentView.swift
//  Shared
//
//  Created by Yong Jin on 2022/1/1.
//

import SwiftUI

struct ContentView: View {
    var swifter: Swifter = Swifter(consumerKey: "wa43gWPPaNLYiZCdvZLXlA",
                                   consumerSecret: "BvKyqaWgze9BP3adOSTtsX6PnBOG5ubOwJmGpwh8w")
    var body: some View {
        
        Button {
            swifter.authorize(withProvider: swifter, callbackURL: URL(string: "fetchmee://success")!, success: {token, response in
                print(token)
            })
        } label: {
            Text("Login")
        }
        .frame(width: 300, height: 500, alignment: .center)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
