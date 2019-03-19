//
//  ADUserTests.swift
//  NoMAD-ADAuthTests
//
//  Created by Josh Wisenbaker on 3/17/19.
//  Copyright © 2019 Jamf. All rights reserved.
//

import XCTest
@testable import NoMAD_ADAuth

class ADUserRecordTests: XCTestCase {

    let sut = ADUserRecord(userPrincipal: "test.princ",
                           firstName: "Test",
                           lastName: "User",
                           fullName: "Test User",
                           shortName: "testuser",
                           upn: "test.user",
                           email: "test.user@sut.com",
                           groups: ["Test Group One", "Test Group Two"],
                           homeDirectory: nil,
                           passwordSet: Date(),
                           passwordExpire: Date().addingTimeInterval(36000.0),
                           uacFlags: nil,
                           passwordAging: true,
                           computedExireDate: nil,
                           updatedLast: Date(),
                           domain: "test.domain",
                           cn: "cn=test",
                           customAttributes: ["TestCustomKey": "TestCustomValue"])

    func testEquatableTrue() {
        XCTAssertEqual(sut, sut, "Equatable true failed")
    }

    func testEquatableFalse() {
        var sutFirstDiff = sut
        sutFirstDiff.firstName = "Bobby"

        XCTAssertNotEqual(sut, sutFirstDiff, "These two user structs shoould not be equal.")
    }

}
