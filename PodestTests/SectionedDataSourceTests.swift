//
//  SectionedDataSourceTests.swift
//  PodestTests
//
//  Created by Michael on 10/9/17.
//  Copyright © 2017 Michael Nisi. All rights reserved.
//

import XCTest
import UIKit

@testable import Podest

class SectionedDataSourceTests: XCTestCase {
  
  class TestDataSource: SectionedDataSource {

    enum SectionID: Int {
      case a, b, c
    }

    struct Item: Equatable {
      let id: SectionID
      let name: String
    }

    var sections = [Section<Item>]()
    
    private static func makeSections(items: [Item]) -> [Section<Item>] {
      var a = Section<Item>(title: "A")
      var b = Section<Item>(title: "B")
      var c = Section<Item>(title: "C")

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
    
    static func makeUpdates(
      sections current: [Section<Item>],
      items: [Item]
    ) -> ([Section<Item>], Updates){
      let sections = TestDataSource.makeSections(items: items)
      let updates = TestDataSource.makeUpdates(old: current, new: sections)
      
      return (sections, updates)
    }
    
  }
  
  fileprivate var ds: TestDataSource!
  
  override func setUp() {
    super.setUp()

    ds = TestDataSource()
  }
  
  override func tearDown() {
    super.tearDown()
  }
  
  func testUpdates() {
    let items = [
      TestDataSource.Item(id: .a, name: "abc")
    ]
    
    do {
      let wanted = Updates()

      wanted.insertSection(at: 0)
      wanted.insertRow(at: IndexPath(row: 0, section: 0))

      let (sections, found) = TestDataSource.makeUpdates(
        sections: ds.sections,
        items: items
      )

      XCTAssertEqual(found, wanted)

      ds.sections = sections
    }
    
    do {
      let wanted = [Section<TestDataSource.Item>(title: "A", items: items)]
      XCTAssertEqual(ds.sections, wanted)
    }
  }
  
}
