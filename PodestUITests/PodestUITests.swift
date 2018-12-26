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

  func testSearch() {
    if UIDevice.current.userInterfaceIdiom == .pad {
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

    searchSearchField.tap()
    searchSearchField.typeText("Mo")

    snapshot("3")

    app/*@START_MENU_TOKEN@*/.tables["Search results"].staticTexts["monocle"]/*[[".otherElements[\"Double-tap to dismiss\"].tables[\"Search results\"]",".cells.staticTexts[\"monocle\"]",".staticTexts[\"monocle\"]",".tables[\"Search results\"]"],[[[-1,3,1],[-1,0,1]],[[-1,2],[-1,1]]],[0,0]]@END_MENU_TOKEN@*/.tap()

    snapshot("4")

    app/*@START_MENU_TOKEN@*/.tables["Search results"].staticTexts["Monocle 24: The Urbanist"]/*[[".otherElements[\"Double-tap to dismiss\"].tables[\"Search results\"]",".cells.staticTexts[\"Monocle 24: The Urbanist\"]",".staticTexts[\"Monocle 24: The Urbanist\"]",".tables[\"Search results\"]"],[[[-1,3,1],[-1,0,1]],[[-1,2],[-1,1]]],[0,0]]@END_MENU_TOKEN@*/.tap()

    snapshot("5")

    app.navigationBars["Queue"].buttons["Queue"].tap()
    app.buttons["Cancel"].tap()
  }

  func testBrowseReadPlay() {
    snapshot("0")

    app.tables/*@START_MENU_TOKEN@*/.staticTexts["Bonus Episode: Chris Anderson on the Ezra Klein Show"]/*[[".cells.staticTexts[\"Bonus Episode: Chris Anderson on the Ezra Klein Show\"]",".staticTexts[\"Bonus Episode: Chris Anderson on the Ezra Klein Show\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
    app/*@START_MENU_TOKEN@*/.textViews.containing(.link, identifier:"TED.com").element/*[[".scrollViews.textViews.containing(.link, identifier:\"TED.com\").element",".textViews.containing(.link, identifier:\"TED.com\").element"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

    snapshot("1")

    let window = app.children(matching: .window).element(boundBy: 0)

    window.children(matching: .other).element
      .children(matching: .other)
      .element(boundBy: 1).staticTexts["21: 'N'em"].tap()

    let payButton = window.children(matching: .other).element(boundBy: 1)
      .children(matching: .other).element
      .children(matching: .other).element
      .children(matching: .other).element
      .children(matching: .other).element(boundBy: 1)
      .children(matching: .other).element


    let exists = NSPredicate(format: "exists == 1")

    expectation(for: exists, evaluatedWith: payButton, handler: nil)
    waitForExpectations(timeout: 5, handler: nil)

    payButton.tap()

    snapshot("2")
  }

}
