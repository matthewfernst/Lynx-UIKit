//
//  Support.swift
//  Lynx
//
//  Created by Matthew Ernst on 1/22/23.
//

import Foundation
import UIKit

struct Support
{
    var setting: Setting
    var link: String
}

extension Support
{
 static let supportOptions: [Support] = [
        .init(setting: .init(name: "Follow me on GitHub", iconImage: UIImage(named: "githubIcon"), backgroundColor: .black), link: Constants.github),
        .init(setting: .init(name: "Follow me on Twitter", iconImage: UIImage(named: "twitterIcon"), backgroundColor: .twitterBlue), link: Constants.twitter)
    ]
}
