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
  
  enum TestSectionID: Int {
    case a, b, c
  }
  
  struct TestData: Equatable {
    let id: TestSectionID
    let name: String
  }
  
  class TestDataSource: SectionedDataSource {
    typealias Item = TestData
    var sections = [Section<TestData>]()
    var itemsByIndexPath = [IndexPath : TestData]()
    
    var items = [TestData]() {
      didSet {
        itemsByIndexPath = [IndexPath : TestData]()
      }
    }
    
    private static func makeSections(items: [TestData]) -> [Section<TestData>] {
      var a = Section<TestData>(id: TestSectionID.a.rawValue, title: "A")
      var b = Section<TestData>(id: TestSectionID.b.rawValue, title: "B")
      var c = Section<TestData>(id: TestSectionID.c.rawValue, title: "C")

      for item in items {
        switch item.id {
        case .a:
          a.append(item: item)
        case .b:
          b.append(item: item)
        case .c:
          c.append(item: item)
        }
      }
      
      return [a, b, c].filter {
        !$0.items.isEmpty
      }
    }
    
    func updates(for items: [TestData]) -> Updates {
      self.items = items
      
      let sections = TestDataSource.makeSections(items: items)
      let updates = self.add(merging: sections)
      
      self.sections = sections
      
      return updates
    }
    
  }
  
  fileprivate var ds: TestDataSource!
  
  override func setUp() {
    super.setUp()
    ds = TestDataSource()
  }
  
  override func tearDown() {
    ds = nil
    super.tearDown()
  }
  
  func testUpdates() {
    let items = [
      TestData(id: TestSectionID.a, name: "abc")
    ]
    
    do {
      let wanted = Updates()
      wanted.insertSection(at: 0)
      wanted.insertRow(at: IndexPath(row: 0, section: 0))
      let found = ds.updates(for: items)
      XCTAssertEqual(found, wanted)
    }
    
    do {
      let wanted = [Section<TestData>(id: TestSectionID.a.rawValue, title: "A")]
      XCTAssertEqual(ds.sections, wanted)
    }
  }
  
}
