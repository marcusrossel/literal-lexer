//
//  LiteralLexer Tests.swift
//  LiteralLexer Tests
//
//  Created by Marcus Rossel on 07.09.16.
//  Copyright © 2016 Marcus Rossel. All rights reserved.
//

import XCTest

class LiteralLexerTests: XCTestCase {
  var literalLexer = LiteralLexer()

  private func allTokens(in string: String) -> [Token] {
    literalLexer.text = string
    literalLexer.position = 0
    var tokens = [Token]()

    while true {
      let token = literalLexer.nextToken()
      guard token != .endOfText else { break }
      tokens.append(token)
    }

    return tokens
  }

  func testSpaces() {
    XCTAssertEqual(allTokens(in: "   "), [])
  }

  func testUndefindes() {
    XCTAssertEqual(allTokens(in: " a "), [.undefined("a")])
    XCTAssertEqual(allTokens(in: "a "), [.undefined("a")])
    XCTAssertEqual(allTokens(in: " a"), [.undefined("a")])
    XCTAssertEqual(allTokens(in: "a"), [.undefined("a")])
  }

  func testNewLines() {
    XCTAssertEqual(allTokens(in: " \n "), [.newLine])
    XCTAssertEqual(allTokens(in: "\n "), [.newLine])
    XCTAssertEqual(allTokens(in: " \n"), [.newLine])
    XCTAssertEqual(allTokens(in: "\n"), [.newLine])
    XCTAssertEqual(allTokens(in: "a\n"), [.undefined("a"), .newLine])
    XCTAssertEqual(allTokens(in: "\na"), [.newLine, .undefined("a")])
  }

  func testComments() {
    XCTAssertEqual(
      allTokens(in: "a//abc\n/ "),
      // Explicit `Token.` is needed to resolve ambiguity.
      [.undefined("a"), Token.comment("abc\n/ ")]
    )
    XCTAssertEqual(
      allTokens(in: " a/*Hi world.**/\nb"),
      // Explicit `Token.` is needed to resolve ambiguity.
      [.undefined("a"), Token.comment("Hi world.*"), .newLine, .undefined("b")]
    )
    XCTAssertEqual(
      allTokens(in: "/**//*a*/"),
      [.comment(""), .comment("a")]
    )
  }

  func testBooleans() {
    XCTAssertEqual(allTokens(in: "true"), [.boolean(true)])
    XCTAssertEqual(allTokens(in: "false"), [.boolean(false)])
    XCTAssertEqual(
      allTokens(in: "true false"),
      [.boolean(true), .boolean(false)]
    )
    XCTAssertEqual(
      allTokens(in: "false true"),
      [.boolean(false), .boolean(true)]
    )
    XCTAssertEqual(
      allTokens(in: "truefalse"),
      [.boolean(true), .boolean(false)]
    )
    XCTAssertEqual(allTokens(in: "\ntrue"), [.newLine, .boolean(true)])
    XCTAssertEqual(allTokens(in: "false\n"), [.boolean(false), .newLine])
    XCTAssertEqual(
      allTokens(in: "trufalse"),
      [.undefined("t"), .undefined("r"), .undefined("u"), .boolean(false)]
    )
    XCTAssertEqual(
      allTokens(in: "falstrue"),
      [.undefined("f"),
       .undefined("a"),
       .undefined("l"),
       .undefined("s"),
       .boolean(true)
      ]
    )
  }

  func testIntegers() {
    XCTAssertEqual(allTokens(in: "123_22__"), [.integer(12322)])
    XCTAssertEqual(allTokens(in: "-0_125"), [.integer(-125)])
    XCTAssertEqual(allTokens(in: "0b110"), [.integer(6)])
    XCTAssertEqual(allTokens(in: "-0b125"), [.integer(-1), .integer(25)])
    XCTAssertEqual(allTokens(in: "0o125"), [.integer(85)])
    XCTAssertEqual(allTokens(in: "0x125"), [.integer(293)])
    XCTAssertEqual(allTokens(in: "0xaB_cD"), [.integer(43981)])
    XCTAssertEqual(allTokens(in: "-0o123"), [.integer(-83)])
    XCTAssertEqual(
      allTokens(in: "0o911"),
      [.integer(0), .undefined("o"), .integer(911)]
    )
    XCTAssertEqual(
      allTokens(in: "-_231"),
      [.undefined("-"), .undefined("_"), .integer(231)]
    )
    XCTAssertEqual(
      allTokens(in: "-_012"),
      [.undefined("-"), .undefined("_"), .integer(12)]
    )
  }

  func testFloatingPoints() {
    XCTAssertEqual(allTokens(in: "3.1415"), [.floatingPoint(3.1415)])
    XCTAssertEqual(allTokens(in: "-2.7182818"), [.floatingPoint(-2.7182818)])
    XCTAssertEqual(allTokens(in: "4_123.12_3_"), [.floatingPoint(4123.123)])
    XCTAssertEqual(
      allTokens(in: "3_.14"),
      [.integer(3), .undefined("."), .integer(14)]
    )
    XCTAssertEqual(
      allTokens(in: "7_._00"),
      [.integer(7), .undefined("."), .undefined("_"), .integer(0)]
    )
    XCTAssertEqual(allTokens(in: ".123"), [.undefined("."), .integer(123)])
    XCTAssertEqual(allTokens(in: "123."), [.integer(123), .undefined(".")])
  }

  func testCharacters() {
    XCTAssertEqual(allTokens(in: " 'a' "), [.character("a")])
    XCTAssertEqual(allTokens(in: "'a' "), [.character("a")])
    XCTAssertEqual(allTokens(in: " 'a'"), [.character("a")])
    XCTAssertEqual(allTokens(in: "'a'"), [.character("a")])
    XCTAssertEqual(
      allTokens(in: "'h''i''.'"),
      [.character("h"), .character("i"), .character(".")]
    )
    XCTAssertEqual(allTokens(in: "'1'"), [.character("1")])
  }

  func testUninterpolatedStrings() {
    XCTAssertEqual(allTokens(in: " \"\" "), [.uninterpolatedString("")])
    XCTAssertEqual(allTokens(in: "\"\" "), [.uninterpolatedString("")])
    XCTAssertEqual(allTokens(in: " \"\""), [.uninterpolatedString("")])
    XCTAssertEqual(allTokens(in: "\"\""), [.uninterpolatedString("")])
    XCTAssertEqual(allTokens(in: "\"123\""), [.uninterpolatedString("123")])
    XCTAssertEqual(
      allTokens(in: "a\"hi, world.\"b"),
      // Explicit `Token.` is needed to resolve ambiguity.
      [.undefined("a"),
       Token.uninterpolatedString("hi, world."),
       .undefined("b")
      ]
    )
    XCTAssertEqual(
      allTokens(in: "\"\"_\"\""),
      // Explicit `Token.` is needed to resolve ambiguity.
      [.uninterpolatedString(""),
       Token.undefined("_"),
       .uninterpolatedString("")
      ]
    )
  }

  func testFlags() {
    XCTAssertEqual(allTokens(in: " -f "), [.flag("f")])
    XCTAssertEqual(allTokens(in: "-f "), [.flag("f")])
    XCTAssertEqual(allTokens(in: " -f"), [.flag("f")])
    XCTAssertEqual(allTokens(in: "-f"), [.flag("f")])
    XCTAssertEqual(allTokens(in: "-flag"), [.flag("flag")])
    // Explicit `Token.` is needed to resolve ambiguity.
    XCTAssertEqual(allTokens(in: "a-fla"), [Token.undefined("a"), .flag("fla")])
    // Explicit `Token.` is needed to resolve ambiguity.
    XCTAssertEqual(allTokens(in: "-fl a"), [Token.flag("fl"), .undefined("a")])
    XCTAssertEqual(allTokens(in: "-numer1cFl4g"), [.flag("numer1cFl4g")])
    XCTAssertEqual(
      allTokens(in: "-123.3 -flaggyFlag"),
      [.floatingPoint(-123.3), .flag("flaggyFlag")]
    )
  }

  func testAllTokens() {
    let text = "\"id\" -a1 '$' -1_000.1 + 0x0FF_12A /*.*/ true \n// blegh"
    // Explicit `Token.` is needed to resolve compiler errors.
    let tokens: [Token] = [
      .uninterpolatedString("id"),
      Token.flag("a1"),
      Token.character("$"),
      .floatingPoint(-1000.1),
      Token.undefined("+"),
      .integer(0xFF12A),
      Token.comment("."),
      .boolean(true),
      .newLine,
      Token.comment(" blegh")
    ]

    XCTAssertEqual(allTokens(in: text), tokens)
  }
}
