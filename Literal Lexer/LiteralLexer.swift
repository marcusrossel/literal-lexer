//
//  LiteralLexer.swift
//  Literal Lexer
//
//  Created by Marcus Rossel on 14.09.16.
//  Copyright © 2016 Marcus Rossel. All rights reserved.
//

import Foundation

final class LiteralLexer: LexerProtocol {
  var text = ""
  var position = 0
  var endOfFile: Character = "\0"

  var defaultTransform: (inout Character, LiteralLexer) -> Token = {
    buffer, _ in .undefined(buffer)
  }
  var tokenTransforms = [
    TokenTransform.forWhitespaces,
    TokenTransform.forEndOfFile,
    TokenTransform.forNewLines,
    TokenTransform.forComments,
    TokenTransform.forBooleans,
    TokenTransform.forNumbers,
    TokenTransform.forCharacters,
    TokenTransform.forUninterpolatedStrings,
    TokenTransform.forFlags
  ]
}
