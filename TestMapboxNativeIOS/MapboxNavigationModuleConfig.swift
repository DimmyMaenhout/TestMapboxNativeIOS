//
//  MapboxNavigationModuleConfig.swift
//  TestMapboxNativeIOS
//
//  Created by Dimmy Maenhout on 20/12/2021.
//

import Foundation

class MapboxNavigationModuleConfig {
    let accessToken: String
    var locale: String
    var enableLogging: Bool
    
    init(accessToken: String, locale: String, enableLogging: Bool) {
        self.accessToken = accessToken
        self.locale = locale
        self.enableLogging = enableLogging
    }
}
