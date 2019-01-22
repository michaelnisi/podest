//
//  SectionedDataSourceTests.swift
//  PodestTests
//
//  Created by Michael on 10/9/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import XCTest
import UIKit

@testable import PodKit

class SectionedDataSourceTests: XCTestCase {

  class TestDataSource: SectionedDataSource {

    enum SectionID: Int {
      case a, b, c
    }

    struct Item: Hashable {
      let id: SectionID
      let name: String
    }

    var sections = [Array<Item>]()

    private static func makeSections(items: [Item]) -> [Array<Item>] {
      var a = [Item]()
      var b = [Item]()
      var c = [Item]()

      for item in items {
        switch item.id {
        case .a:
          a.append(item)
        case .b:
          b.append(item)
        case .c:
          c.append(item)
        }
      }

      return [a, b, c].filter { !$0.isEmpty }
    }

//    static func makeUpdates(
//      sections current: [Array<Item>],
//      items: [Item]
//      ) -> ([Array<Item>], Updates){
//      let sections = TestDataSource.makeSections(items: items)
//      let updates = TestDataSource.makeUpdates(old: current, new: sections)
//
//      return (sections, updates)
//    }

  }

  fileprivate var ds: TestDataSource!

  override func setUp() {
    super.setUp()

    ds = TestDataSource()
  }

  override func tearDown() {
    super.tearDown()
  }

  // These outdated tests need to be rewritten.

//  func testUpdates() {
//    let items = [
//      TestDataSource.Item(id: .a, name: "abc")
//    ]
//
//    do {
//      let wanted = Updates()
//
//      wanted.insertSection(at: 0)
//      wanted.insertRow(at: IndexPath(row: 0, section: 0))
//
//      let (sections, found) = TestDataSource.makeUpdates(
//        sections: ds.sections,
//        items: items
//      )
//
//      XCTAssertEqual(found, wanted)
//
//      ds.sections = sections
//    }
//
//    do {
//      let wanted = [items]
//      XCTAssertEqual(ds.sections, wanted)
//    }
//  }

  func testSectionEquality() {
    let a = [TestDataSource.Item]()

    XCTAssertEqual(a, a)

    let b = [TestDataSource.Item]()

    XCTAssertEqual(a, b)

    let c = [TestDataSource.Item(id: .a, name: "One")]

    XCTAssertNotEqual(a, c)

    let d = [TestDataSource.Item(id: .a, name: "One")]

    XCTAssertEqual(c, d)
  }

}
