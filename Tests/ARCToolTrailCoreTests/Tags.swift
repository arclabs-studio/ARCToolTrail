//
//  Tags.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Testing

extension Tag {
    /// Pure logic, no I/O.
    @Tag static var unit: Self
    /// Real pipeline across several components or the file system.
    @Tag static var integration: Self
    /// Behaviour the product's numbers depend on.
    @Tag static var critical: Self
}
