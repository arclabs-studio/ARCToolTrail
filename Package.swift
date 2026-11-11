// swift-tools-version: 6.0
//
//  Package.swift
//  ARCToolTrail
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import PackageDescription

let package = Package(name: "ARCToolTrail",

                      // MARK: - Platforms

                      platforms: [.macOS(.v14)],

                      // MARK: - Products

                      products: [.executable(name: "tooltrail", targets: ["tooltrail"]),
                                 .library(name: "ARCToolTrailCore", targets: ["ARCToolTrailCore"])],

                      // MARK: - Dependencies

                      dependencies: [.package(url: "https://github.com/apple/swift-argument-parser",
                                              from: "1.8.2")],

                      // MARK: - Targets

                      targets: [.target(name: "ARCToolTrailCore",
                                        resources: [.process("Resources")]),
                                .executableTarget(name: "tooltrail",
                                                  dependencies: ["ARCToolTrailCore",
                                                                 .product(name: "ArgumentParser",
                                                                          package: "swift-argument-parser")]),
                                .testTarget(name: "ARCToolTrailCoreTests",
                                            dependencies: ["ARCToolTrailCore"],
                                            resources: [.copy("Fixtures")])])
