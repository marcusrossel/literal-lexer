//
//  LiteralLexer.swift
//  Literal Lexer
//
//  Created by Marcus Rossel on 14.09.16.
//  Copyright © 2016 Marcus Rossel. All rights reserved.
//

import Foundation

/// A typealias needed to avoid circular referencing.
typealias LiteralLexerToken = Token

final class LiteralLexer : LexerProtocol {
  typealias Token = LiteralLexerToken

  var text = ""
  var position = 0
  var endOfText: Character = "\0"

  var defaultTransform = TokenTransform.default
  var tokenTransforms = [
    TokenTransform.forWhitespaces,
    TokenTransform.forEndOfText,
    TokenTransform.forNewLines,
    TokenTransform.forComments,
    TokenTransform.forBooleans,
    TokenTransform.forNumbers,
    TokenTransform.forCharacters,
    TokenTransform.forUninterpolatedStrings,
    TokenTransform.forFlags
  ]
}
