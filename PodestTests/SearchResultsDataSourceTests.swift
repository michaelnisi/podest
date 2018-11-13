//
//  SearchResultsDataSourceTests.swift
//  Podest
//
//  Created by Michael on 1/8/16.
//  Copyright © 2016 Michael Nisi. All rights reserved.
//

import XCTest
@testable import Podest

class SearchResultsDataSourceTests: XCTestCase {
  
  var ds: SearchResultsDataSource!
  
  override func setUp() {
    super.setUp()
    ds = SearchResultsDataSource()
  }
  
  override func tearDown() {
    super.tearDown()
  }
  
  func testInit() {
    XCTAssert(ds.sections.isEmpty)
    // XCTAssert(ds.itemsByIndexPath.isEmpty)
  }

  func testEmpty() {
    do {
      let found = ds.sectionsFor(items: []	)
      XCTAssert(found.isEmpty)
    }
    do {
      let updates = ds.updatesForItems(items: [])
      XCTAssertEqual(updates.sectionsToInsert.count, 0)
      XCTAssertEqual(updates.sectionsToReload.count, 0)
      XCTAssertEqual(updates.sectionsToDelete.count, 0)
      XCTAssert(updates.rowsToInsert.isEmpty)
      XCTAssert(updates.rowsToReload.isEmpty)
      XCTAssert(updates.rowsToDelete.isEmpty)
    }
  }
}
