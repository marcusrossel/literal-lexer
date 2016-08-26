//
//  main.swift
//  Literal Lexer
//
//  Created by Marcus Rossel on 13.08.16.
//  Copyright © 2016 Marcus Rossel. All rights reserved.
//

import Foundation

/*TESTS*/
let lexer = Lexer<Token>(defaultTransform: { buffer, _ in .undefined(buffer) })

lexer.tokenTransforms = [
  TokenTransform.forWhitespaces,
  TokenTransform.forEndOfFile,
  TokenTransform.forNewLines,
  TokenTransform.forComments,
  TokenTransform.forBooleans,
  TokenTransform.forFloatingPoints,
  TokenTransform.forIntegers,
]

func test(message: String, reset: Bool = true, texts: String...) {
  for (index, text) in texts.enumerated() {
    print("\(message) \(index):")
    lexer.text = text
    var tokenBuffer = Token.endOfFile
    while true {
      tokenBuffer = lexer.nextToken()
      print("\t\(tokenBuffer)")
      if case Token.endOfFile = tokenBuffer { break }
    }
    if reset { lexer.position = 0 }
  }
}

let domains: Set = [
  "SPACE",
  "UNDEFINED",
  "NEW_LINE",
  "COMMENT",
  "BOOL",
  "FLOAT",
  "INT",
]

if domains.contains("SPACE") {
  test(message: "SPACE", texts: "   ")
}

if domains.contains("UNDEFINED") {
  test(message: "UNDEFINED", texts:
    " a ",
    "a " ,
    " a" ,
    "a"
  )
}

if domains.contains("NEW_LINE") {
  test(message: "NEW_LINE", texts:
    " \na " ,
    "\na "  ,
    " \na"  ,
    " \n a ",
    "\n a"  ,
    "a\n"   ,
    " a\n"
  )
}

if domains.contains("COMMENT") {
  test(message: "COMMENT", texts:
    " a//abc\n ",
    " a b/*Hello world.*/\nc"
  )
}

if domains.contains("BOOL") {
  test(message: "BOOL", texts:
    "true",
    "false",
    "true false",
    "false true",
    "falsetrue",
    "\nfalse",
    "true\n",
    "falstrue",
    "trufalse"
  )
}

if domains.contains("FLOAT") {
  test(message: "FLOAT", texts:
    "3.1415926535897",
    "-2.718281828",
    "4_123.123_11_",
    "3_.14", // shouldn't work if poosible
    "7_._00", // shouldn't work if poosible
    ".123",
    "123."
  )
}


if domains.contains("INT") {
  test(message: "INT", texts:
    "123_22__",
    "-0_125"  ,
    "0b110"   ,
    "-0b125"  ,
    "0o125"   ,
    "0x125"   ,
    "-0o123"  ,
    "0o911"   ,
    "-_231"   ,
    "-_012"
  )
}
