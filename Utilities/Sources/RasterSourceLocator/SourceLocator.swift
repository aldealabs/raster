//
//  File.swift
//  
//
//  Created by YuAo on 2020/3/16.
//

import Foundation

public func RasterSourcesRootURL(in projectRoot: URL) -> URL {
    return projectRoot.appendingPathComponent("Frameworks/Raster/")
}
