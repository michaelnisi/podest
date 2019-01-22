//
//  PodestUITests.swift
//  PodestUITests
//
//  Created by Michael Nisi on 23.12.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import XCTest

class PodestUITests: XCTestCase {

  var app: XCUIApplication!

  override func setUp() {
    continueAfterFailure = false

    app = XCUIApplication()

    setupSnapshot(app)
    app.launch()
  }

  func testSearching() {
    let detail = app.tables.cells.element(boundBy: 0)

    expectation(
      for: NSPredicate(format: "exists == 1"),
      evaluatedWith: detail,
      handler: nil
    )

    waitForExpectations(timeout: 5, handler: nil)

    if UIDevice.current.userInterfaceIdiom == .pad {
      detail.tap()

      app.statusBars
        .children(matching: .other).element
        .children(matching: .other).element
        .children(matching: .other).element(boundBy: 0).tap()
    } else {
      app.statusBars
        .children(matching: .other).element
        .children(matching: .other).element(boundBy: 0).tap()
    }

    let searchSearchField = app.searchFields["Search"]

    expectation(
      for: NSPredicate(format: "exists == 1"),
      evaluatedWith: searchSearchField,
      handler: nil
    )

    waitForExpectations(timeout: 5, handler: nil)

    searchSearchField.tap()
    searchSearchField.typeText("Mon")

    let suggestion = app
      .tables["Search results"].staticTexts["monocle"]

    expectation(
      for: NSPredicate(format: "exists == 1"),
      evaluatedWith: suggestion,
      handler: nil
    )

    waitForExpectations(timeout: 5, handler: nil)

    snapshot("4")
    suggestion.tap()

    let find = app
      .tables["Search results"].staticTexts["Monocle 24: The Urbanist"]

    expectation(
      for: NSPredicate(format: "exists == 1"),
      evaluatedWith: find,
      handler: nil
    )

    waitForExpectations(timeout: 5, handler: nil)

    snapshot("5")
    find.firstMatch.tap()

    let episode = app.tables.cells.element(boundBy: 0)

    expectation(
      for: NSPredicate(format: "exists == 1"),
      evaluatedWith: episode,
      handler: nil
    )

    waitForExpectations(timeout: 5, handler: nil)

    episode.tap()
    snapshot("6")

    app.navigationBars["Queue"].buttons["Queue"].tap()
    app.buttons["Cancel"].tap()
  }

  func testPlaying() {
    let window = app.children(matching: .window).element(boundBy: 0)

    window.children(matching: .other).element
      .children(matching: .other)
      .element(boundBy: 1).staticTexts["#130 The Snapchat Thief"].tap()

    let play = window.children(matching: .other).element(boundBy: 1)
      .children(matching: .other).element
      .children(matching: .other).element
      .children(matching: .other).element
      .children(matching: .other).element(boundBy: 1)
      .children(matching: .other).element

    expectation(
      for: NSPredicate(format: "exists == 1"),
      evaluatedWith: play,
      handler: nil
    )

    waitForExpectations(timeout: 5, handler: nil)

    play.tap()
    snapshot("3")
  }

  func testBrowsing() {
    let cell = app.tables.cells.element(boundBy: 0)

    expectation(
      for: NSPredicate(format: "exists == 1"),
      evaluatedWith: cell,
      handler: nil
    )

    waitForExpectations(timeout: 5, handler: nil)

    if UIDevice.current.userInterfaceIdiom == .phone {
      snapshot("0")
    }

    cell.tap()

    let feedButton = app.scrollViews.otherElements.buttons.element(boundBy: 0)

    expectation(
      for: NSPredicate(format: "exists == 1"),
      evaluatedWith: feedButton,
      handler: nil
    )

    waitForExpectations(timeout: 5, handler: nil)
    
    snapshot("1")

    feedButton.tap()
    sleep(1)

    if UIDevice.current.userInterfaceIdiom == .phone {
      app.tables.cells.element(boundBy: 0).swipeUp()
    }

    snapshot("2")
  }

}
