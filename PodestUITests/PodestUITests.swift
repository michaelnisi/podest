//
//  PodestUITests.swift
//  PodestUITests
//
//  Created by Michael Nisi on 23.12.18.
//  Copyright © 2018 Michael Nisi. All rights reserved.
//

import XCTest

class PodestUITests: XCTestCase {
  
  struct Script {
    let playerTitle = "#130 The Snapchat Thief"
    let searchTerm = "new"
    let suggestedTerm = "new america"
    let resultTitle = "Adventures in New America"
  }

  var app: XCUIApplication!

  override func setUp() {
    continueAfterFailure = false

    app = XCUIApplication()

    setupSnapshot(app)
    app.launch()
  }
  
  let script = Script()
  
  var window: XCUIElement {
    return app.children(matching: .window).element(boundBy: 0)
  }
  
  var miniPlayer: XCUIElement {
    return window.children(matching: .other)
      .element.children(matching: .other)
      .element(boundBy: 1).staticTexts[script.playerTitle]
  }
  
  var exists = NSPredicate(format: "exists == 1")

  func testSearching() {
    let detail = app.tables.cells.element(boundBy: 0)

    wait(for: [
      expectation(for: exists, evaluatedWith: detail)
    ], timeout: 5)

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

    wait(for: [
      expectation(for: exists, evaluatedWith: searchSearchField)
    ], timeout: 5)
    searchSearchField.tap()
    searchSearchField.typeText(script.searchTerm)

    let suggestion = app
      .tables["Search results"].staticTexts[script.suggestedTerm]

    wait(for: [
      expectation(for: exists,evaluatedWith: suggestion)
    ], timeout: 5)
    snapshot("4")
    suggestion.tap()

    let find = app
      .tables["Search results"].staticTexts[script.resultTitle]

    wait(for: [
      expectation(for: exists, evaluatedWith: find)
    ], timeout: 5)
    snapshot("5")
    find.firstMatch.tap()

    let episode = app.tables.cells.element(boundBy: 0)

    wait(for: [expectation(for: exists, evaluatedWith: episode)], timeout: 5)
    episode.tap()
    snapshot("6")

    app.navigationBars["Queue"].buttons["Queue"].tap()
    app.buttons["Cancel"].tap()
  }

  func testPlaying() {
    wait(for: [
      expectation(for: exists, evaluatedWith: miniPlayer)
    ], timeout: 5)
    miniPlayer.tap()

    let playButton = window.children(matching: .other)
      .element(boundBy: 1).children(matching: .other)
      .element.children(matching: .other)
      .element.children(matching: .other)
      .element.children(matching: .other)
      .element(boundBy: 1).children(matching: .other)
      .element

    wait(for: [
      expectation(for: exists, evaluatedWith: playButton, handler: nil)
    ], timeout: 5)
    playButton.tap()
    snapshot("3")
  }

  func testBrowsing() {
    let secondCell = app.tables.cells.element(boundBy: 1)

    wait(for: [
      expectation(for: exists, evaluatedWith: secondCell)
    ], timeout: 5)

    if UIDevice.current.userInterfaceIdiom == .phone {
      snapshot("0")
    }

    let cell = app.tables.cells.element(boundBy: 0)
    cell.tap()

    let feedButton = app.scrollViews.otherElements.buttons.element(boundBy: 0)

    wait(for: [
      expectation(for: exists, evaluatedWith: feedButton)
    ], timeout: 5)
    snapshot("1")
    feedButton.tap()
    sleep(1)

    if UIDevice.current.userInterfaceIdiom == .phone,
      app.windows.firstMatch.frame.height < 736 {
      app.tables.cells.element(boundBy: 0).swipeUp()
    }

    snapshot("2")
  }
}
