// Copyright 2023 The MediaPipe Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest

import MPPCommon

@testable import MPPTextClassifier

class TextClassifierTests: XCTestCase {

  static let bundle = Bundle(for: TextClassifierTests.self)
  
  static let kBertModelPath = bundle.path(
    forResource: "bert_text_classifier",
    ofType: "tflite")
  
  static let kPositiveText = "it's a charming and often affecting journey"

  static let kNegativeText = "unflinchingly bleak and desperate"

  static let kBertNegativeTextResults = [
      ResultCategory(
        index: 0, 
        score: 0.956187, 
        categoryName: "negative", 
        displayName: nil),
      ResultCategory(
        index: 1, 
        score: 0.043812, 
        categoryName: "positive", 
        displayName: nil)
      ]

  static let kBertNegativeTextResultsForEdgeTestCases = [
      ResultCategory(
        index: 0, 
        score: 0.956187, 
        categoryName: "negative", 
        displayName: nil),
      ]

  func assertEqualErrorDescriptions(
    _ error: Error, expectedLocalizedDescription:String) {
   XCTAssertEqual(
      error.localizedDescription,
      expectedLocalizedDescription)
  }
  
  func assertCategoriesAreEqual(
    category: ResultCategory, 
    expectedCategory: ResultCategory) {
     XCTAssertEqual(
      category.index,
      expectedCategory.index)
    XCTAssertEqual(
      category.score,
      expectedCategory.score,
      accuracy:1e-6)
    XCTAssertEqual(
      category.categoryName,
      expectedCategory.categoryName)
    XCTAssertEqual(
      category.displayName,
      expectedCategory.displayName)
  }

  func assertEqualCategoryArrays(
    categoryArray: [ResultCategory], 
    expectedCategoryArray:[ResultCategory]) {

    XCTAssertEqual(categoryArray.count, expectedCategoryArray.count)

    for (category, expectedCategory) in 
      zip(categoryArray, expectedCategoryArray)  {
      assertCategoriesAreEqual(
        category:category, 
        expectedCategory:expectedCategory)
    }
  }
  
  func assertTextClassifierResultHasOneHead(
    _ textClassifierResult: TextClassifierResult) {
    XCTAssertEqual(textClassifierResult.classificationResult.classifications.count, 1);
    XCTAssertEqual(textClassifierResult.classificationResult.classifications[0].headIndex, 0);
  }

  func textClassifierOptionsWithModelPath(
    _ modelPath: String?) throws -> TextClassifierOptions {
    let modelPath = try XCTUnwrap(modelPath)

    let textClassifierOptions = TextClassifierOptions();
    textClassifierOptions.baseOptions.modelAssetPath = modelPath;

    return textClassifierOptions
  }

  func assertCreateTextClassifierThrowsError(
    textClassifierOptions: TextClassifierOptions,
    expectedErrorDescription: String) {
    do {
      let textClassifier = try TextClassifier(options:textClassifierOptions)
      XCTAssertNil(textClassifier)
    }
    catch {
      assertEqualErrorDescriptions(
        error, 
        expectedLocalizedDescription: expectedErrorDescription)
    }
  }

  func assertResultsForClassify(
    text: String, 
    using textClassifier: TextClassifier,
    equals expectedCategories: [ResultCategory]) throws {
    let textClassifierResult = 
      try XCTUnwrap(
        textClassifier.classify(text: text));
    assertTextClassifierResultHasOneHead(textClassifierResult);
    assertEqualCategoryArrays(
      categoryArray:
        textClassifierResult.classificationResult.classifications[0].categories,
      expectedCategoryArray: expectedCategories);
  }

  func testCreateTextClassifierWithInvalidMaxResultsFails() throws {
    let textClassifierOptions = 
      try XCTUnwrap(
        textClassifierOptionsWithModelPath(TextClassifierTests.kBertModelPath))
    textClassifierOptions.maxResults = 0

    assertCreateTextClassifierThrowsError(
      textClassifierOptions: textClassifierOptions,
      expectedErrorDescription: """
          INVALID_ARGUMENT: Invalid `max_results` option: value must be != 0.
          """)
  }

  func testCreateTextClassifierWithCategoryAllowlistandDenylistFails() throws {

    let textClassifierOptions = 
      try XCTUnwrap(
        textClassifierOptionsWithModelPath(TextClassifierTests.kBertModelPath))
    textClassifierOptions.categoryAllowlist = ["positive"]
    textClassifierOptions.categoryDenylist = ["positive"]

    assertCreateTextClassifierThrowsError(
      textClassifierOptions: textClassifierOptions,
      expectedErrorDescription: """
          INVALID_ARGUMENT: `category_allowlist` and `category_denylist` are \
          mutually exclusive options.
          """)
  }

  func testClassifyWithBertSucceeds() throws {

    let modelPath = try XCTUnwrap(TextClassifierTests.kBertModelPath)
    let textClassifier = try XCTUnwrap(TextClassifier(modelPath: modelPath))
    
    try assertResultsForClassify(
        text: TextClassifierTests.kNegativeText,
        using: textClassifier,
        equals: TextClassifierTests.kBertNegativeTextResults)
  }

  func testClassifyWithMaxResultsSucceeds() throws {
    let textClassifierOptions = 
      try XCTUnwrap(
        textClassifierOptionsWithModelPath(TextClassifierTests.kBertModelPath))
    textClassifierOptions.maxResults = 1

    let textClassifier = 
      try XCTUnwrap(TextClassifier(options: textClassifierOptions))

    try assertResultsForClassify(
        text: TextClassifierTests.kNegativeText,
        using: textClassifier,
        equals: TextClassifierTests.kBertNegativeTextResultsForEdgeTestCases)
  }

  func testClassifyWithCategoryAllowlistSucceeds() throws {
    let textClassifierOptions = 
      try XCTUnwrap(
        textClassifierOptionsWithModelPath(TextClassifierTests.kBertModelPath))
    textClassifierOptions.categoryAllowlist = ["negative"];

    let textClassifier = 
      try XCTUnwrap(TextClassifier(options: textClassifierOptions))
    
    try assertResultsForClassify(
        text: TextClassifierTests.kNegativeText,
        using: textClassifier,
        equals: TextClassifierTests.kBertNegativeTextResultsForEdgeTestCases)
  }

  func testClassifyWithCategoryDenylistSucceeds() throws {
    let textClassifierOptions = 
      try XCTUnwrap(
        textClassifierOptionsWithModelPath(TextClassifierTests.kBertModelPath))
    textClassifierOptions.categoryDenylist = ["positive"];

    let textClassifier = 
      try XCTUnwrap(TextClassifier(options: textClassifierOptions))
    
    try assertResultsForClassify(
        text: TextClassifierTests.kNegativeText,
        using: textClassifier,
        equals: TextClassifierTests.kBertNegativeTextResultsForEdgeTestCases)
  }

  func testClassifyWithScoreThresholdSucceeds() throws {
    let textClassifierOptions = 
      try XCTUnwrap(
        textClassifierOptionsWithModelPath(TextClassifierTests.kBertModelPath))
    textClassifierOptions.scoreThreshold = 0.5;

    let textClassifier = 
      try XCTUnwrap(TextClassifier(options: textClassifierOptions))
    
    try assertResultsForClassify(
        text: TextClassifierTests.kNegativeText,
        using: textClassifier,
        equals: TextClassifierTests.kBertNegativeTextResultsForEdgeTestCases)
  }

}
