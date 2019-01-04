//
//  ListDataSourceTests.swift
//  PodKitTests
//
//  Created by Michael Nisi on 04.01.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import XCTest
import FeedKit

@testable import PodKit

class ListDataSourceTests: XCTestCase {

  override func setUp() {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }
  
  func testSummaryItemEquality() {
    let text = NSAttributedString(string: "Hello")
    let a = ListDataSource.Item.summary(text)
    let b = ListDataSource.Item.summary(text)

    XCTAssertEqual(a, b)

    let c = ListDataSource.Item.message(text)

    XCTAssertNotEqual(a, c)
  }

  func testMessageItemEquality() {
    let text = NSAttributedString(string: "Hello")
    let a = ListDataSource.Item.message(text)
    let b = ListDataSource.Item.message(text)

    XCTAssertEqual(a, b)

    let c = ListDataSource.Item.summary(text)

    XCTAssertNotEqual(a, c)
  }

  func testEntryItemEquality() {
    let bundle = Bundle(for: ListDataSourceTests.self)
    let url = bundle.url(forResource: "entries", withExtension: "json")!
    let json = try! Data(contentsOf: url)
    let decoder = JSONDecoder()

    let entries = try! decoder.decode([Entry].self, from: json)

    let a = ListDataSource.Item.entry(entries[0])
    let b = ListDataSource.Item.entry(entries[0])

    XCTAssertEqual(a, b)

    let c = ListDataSource.Item.entry(entries[1])

    XCTAssertNotEqual(a, c)
  }
  
}
