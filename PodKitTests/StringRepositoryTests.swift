//
//  StringRepositoryTests.swift
//  PodKitTests
//
//  Created by Michael Nisi on 25.01.19.
//  Copyright © 2019 Michael Nisi. All rights reserved.
//

import XCTest
import FeedKit

@testable import PodKit

class StringRepositoryTests: XCTestCase {

  struct EntrySubtitles: Codable {
    let entries: [Entry]
    let subtitles: [String]
  }

  struct TestData: Codable {
    let entrySubtitles: EntrySubtitles
  }

  lazy var entrySubtitles: EntrySubtitles = {
    let bundle = Bundle(for: ListDataSourceTests.self)
    let url = bundle.url(forResource: "strings", withExtension: "json")!
    let json = try! Data(contentsOf: url)
    let decoder = JSONDecoder()

    let data = try! decoder.decode(TestData.self, from: json)

    return data.entrySubtitles
  }()

  func testEpisodeCellSubtitle() {
    let entries = entrySubtitles.entries
    let subtitles = entrySubtitles.subtitles

    for (i, entry) in entries.enumerated() {
      let found = StringRepository.episodeCellSubtitle(for: entry)
      let wanted = subtitles[i]
      
      XCTAssertEqual(found, wanted)
    }
  }

}
