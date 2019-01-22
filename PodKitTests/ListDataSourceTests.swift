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

  private func loadFeeds() throws -> [Feed] {
    let bundle = Bundle(for: ListDataSourceTests.self)
    let url = bundle.url(forResource: "feeds", withExtension: "json")!
    let json = try Data(contentsOf: url)
    let decoder = JSONDecoder()

    return try decoder.decode([Feed].self, from: json)
  }

  lazy var sharedFeeds: [Feed] = try! loadFeeds()
  
  func testSummaryItemEquality() {
    let feeds = sharedFeeds

    let feed = feeds.first!

    let text = NSAttributedString(string: "Hello")
    
    let a = ListDataSource.Item.feed(feed, text)
    let b = ListDataSource.Item.feed(feed, text)

    XCTAssertEqual(a, b)
  }

  func testMessageItemEquality() {
    let text = NSAttributedString(string: "Hello")

    let a = ListDataSource.Item.message(text)
    let b = ListDataSource.Item.message(text)

    XCTAssertEqual(a, b)
  }

  func testEntryItemEquality() {
    let bundle = Bundle(for: ListDataSourceTests.self)
    let url = bundle.url(forResource: "entries", withExtension: "json")!
    let json = try! Data(contentsOf: url)
    let decoder = JSONDecoder()

    let entries = try! decoder.decode([Entry].self, from: json)

    let firstLine = "The first line of the summary."

    let a = ListDataSource.Item.entry(entries[0], firstLine)
    let b = ListDataSource.Item.entry(entries[0], firstLine)

    XCTAssertEqual(a, b)

    let c = ListDataSource.Item.entry(entries[1], firstLine)

    XCTAssertNotEqual(a, c)
  }
  
}
