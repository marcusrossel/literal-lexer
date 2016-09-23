//
//  Token.swift
//  Literal Lexer
//
//  Created by Marcus Rossel on 11.08.16.
//  Copyright © 2016 Marcus Rossel. All rights reserved.
//

import Foundation

// Helper method.
internal extension Character {
  func isPart(of set: CharacterSet) -> Bool {
    return String(self).rangeOfCharacter(from: set) != nil
  }
}

/// The literals that can be lexed by `LiteralLexer`.
enum Token: Equatable {
  case endOfFile
  case newLine
  case comment(String)

  case boolean(Bool)
  case integer(Int)
  case floatingPoint(Double)
  case character(Character)
  case uninterpolatedString(String)
  case flag(String)

  case undefined(Character)

  static func ==(lhs: Token, rhs: Token) -> Bool {
    switch (lhs, rhs) {
    case (.endOfFile, .endOfFile):                                 return true
    case (.newLine, .newLine):                                     return true
    case let (.comment(l), .comment(r)):                           return l == r
    case let (.boolean(l), .boolean(r)):                           return l == r
    case let (.integer(l), .integer(r)):                           return l == r
    case let (.floatingPoint(l), .floatingPoint(r)):               return l == r
    case let (.character(l), .character(r)):                       return l == r
    case let (.uninterpolatedString(l), .uninterpolatedString(r)): return l == r
    case let (.flag(l), .flag(r)):                                 return l == r
    case let (.undefined(l), .undefined(r)):                       return l == r
    default:                                                       return false
    }
  }
}

/// A namespace for all of the token transforms.
///
/// All of the methods are of the form: `LexerProtocol.PossibleTransform`.
///
/// The parameter `buffer` is the current relevant character and is passed in by
/// `lexer.nextToken()`.
/// When the function returns, `buffer` should be set to the next relevant
/// character.
enum TokenTransform {
  /// Detects and ignores consecutive whitespaces.
  ///
  /// - Returns: `nil`
  static func forWhitespaces(_ buffer: inout Character, _ lexer: LiteralLexer)
  -> Token? {
    while buffer.isPart(of: .whitespaces) {
      buffer = lexer.nextCharacter()
    }
    return nil
  }

  /// Detects the `LiteralLexer.endOfFile` character (`"\0"`).
  ///
  /// - Returns: `.endOfLine` if the respective character was detected,
  /// otherwise `nil`.
  static func forEndOfFile(_ buffer: inout Character, _ lexer: LiteralLexer)
  -> Token? {
    guard buffer == lexer.endOfFile else { return nil }

    buffer = lexer.nextCharacter()
    return .endOfFile
  }

  /// Detects newline characters.
  ///
  /// - Returns: `.newLine` if the respective character was detected,
  /// otherwise `nil`.
  static func forNewLines(_ buffer: inout Character, _ lexer: LiteralLexer)
  -> Token? {
    guard buffer.isPart(of: .newlines) else { return nil }

    buffer = lexer.nextCharacter()
    return .newLine
  }

  /// Detects and returns the contents of open (`//`) and closed (`/**/`)
  /// comments.
  /// Open comments end with the end of `LiteralLexer.text` and can therefore
  /// only be used after all other tokens have appeared.
  ///
  /// - Returns: A `.whitespace` token if a comment was detected, otherwise
  /// `nil`.
  static func forComments(_ buffer: inout Character, _ lexer: LiteralLexer)
  -> Token? {
    guard buffer == "/" else { return nil }

    var commentBuffer = ""

    // Handles open comments.
    if lexer.nextCharacter(peek: true) == "/" {
      // Sets `buffer` to the first character after the second `/`.
      buffer = lexer.nextCharacter(stride: 2)

      // Adds characters to `commentBuffer` until `endOfFile` is reached.
      while buffer != lexer.endOfFile {
        commentBuffer.append(buffer)
        buffer = lexer.nextCharacter()
      }
    } /* Handles closed comments. */
    else if lexer.nextCharacter(peek: true) == "*" {
      // Sets `buffer` to the first character after the `*`.
      buffer = lexer.nextCharacter(stride: 2)

      // Adds comments to `commentBuffer` until `*/` occures.
      while commentBuffer.range(of: "*/", options: .backwards) == nil {
        commentBuffer.append(buffer)
        guard buffer != lexer.endOfFile else {
          fatalError("Lexer Error: Expected `*/`.\n")
        }
        buffer = lexer.nextCharacter()
      }

      // Removes the last two characters (`*/`) from the `commentBuffer`.
      let index = commentBuffer.index(commentBuffer.endIndex, offsetBy: -2)
      commentBuffer = commentBuffer.substring(to: index)
    } /* Handels the case that it's not actually a comment. */ else {
      return nil
    }

    return .comment(commentBuffer)
  }

  /// Detects boolean literals (`true` or `false`).
  ///
  /// - Returns: A `.boolean` token if a boolean literal was detected, otherwise
  /// `nil`.
  static func forBooleans(_ buffer: inout Character, _ lexer: LiteralLexer)
  -> Token? {
    for booleanLiteral in ["true", "false"] {
      var booleanBuffer = "\(buffer)"

      // Appends the number of characters the current `booleanLiteral` would
      // require in a non-consuming manner.
      for position in 1..<booleanLiteral.characters.count {
        booleanBuffer.append(lexer.nextCharacter(peek: true, stride: position))
      }

      if booleanBuffer == booleanLiteral {
        // Turns the previous non-consuming `nextCharacter()` calls into
        // consuming ones.
        buffer = lexer.nextCharacter(stride: booleanLiteral.characters.count)
        // Returns `true` if the current `booleanLiteral` is `"true"` and
        // `false` if not (in which case it's `"false"`).
        return .boolean(booleanLiteral == "true")
      }
    }

    return nil
  }

  /// Detects binary, octal, decimal and hexadecimal integer literals as well as
  /// floating-point literals.
  /// The different integer literal types are denoted by prefixes:
  /// * binary: `0b`
  /// * octal: `0o`
  /// * decimal: no prefix
  /// * hexadecimal: `0x`
  ///
  /// - Returns: An `.integer` token if an integer literal was detected, a 
  /// `.floatingPoint` token if a floating-point token was detected, otherwise
  /// `nil`.
  static func forNumbers(_ buffer: inout Character, _ lexer: LiteralLexer)
  -> Token? {
    // Determines if the number is negative, and if the first character after
    // the sign-character even qualifies for a number.
    let numberIsNegative = buffer == "-"
    let testBuffer = numberIsNegative ? lexer.nextCharacter(peek: true) : buffer

    guard testBuffer.isPart(of: .decimalDigits) else { return nil }
    if numberIsNegative { buffer = lexer.nextCharacter() }

    // An indicator used to eliminate the validity of a decimal point if an
    // integer-literal prefix (`0b`, `0o`, `0x`) has been used.
    var literalMustBeInteger = false

    // Assumes that the number literal will be a decimal integer.
    var validCharacters = "01234567890_"
    var radix = 10

    // Adjusts `validCharacters` and `radix` incase of binary, octal and
    // hexadecimal integer literals.
    nonDecimals: do {
      let peekBuffer = lexer.nextCharacter(peek: true)
      if buffer == "0" && peekBuffer.isPart(of: .letters) {
        switch peekBuffer {
        case "b": validCharacters = "01_"; radix = 2
        case "o": validCharacters = "01234567_"; radix = 8
        case "x": validCharacters = "0123456789abcdefABCDEF_"; radix = 16
        default: break nonDecimals
        }

        // Only if the first character after the prefix is valid, the integer
        // literal can be valid.
        let postPrefix = String(lexer.nextCharacter(peek: true, stride: 2))
        guard validCharacters.contains(postPrefix) else { break nonDecimals }
        literalMustBeInteger = true
        buffer = lexer.nextCharacter(stride: 2)
      }
    }

    var numberBuffer = numberIsNegative ? "-" : ""

    // Condition closure that checks if a decimal point is valid given a certain
    // state.
    let isValidDecimalPoint = { (buffer: Character) -> Bool in
      guard buffer == "." else { return false }
      let nextCharacter = lexer.nextCharacter(peek: true)

      return
        !numberBuffer.contains(".") &&
        numberBuffer.characters.last != "_" &&
        validCharacters.contains(String(nextCharacter)) &&
        nextCharacter != "_"
    }

    // Gets all of the characters that belong to the literal and stores them in
    // `numberBuffer`.
    repeat {
      numberBuffer.append(buffer)
      buffer = lexer.nextCharacter()
    } while
      validCharacters.contains(String(buffer)) || 
      (!literalMustBeInteger && isValidDecimalPoint(buffer))

    let token: Token

    // Removes the `_` characters, because otherwise the number-from-string
    // initializers fail.
    let trimmedBuffer = numberBuffer.replacingOccurrences(of: "_", with: "")

    if trimmedBuffer.contains(".") {
      // Tries to convert the literal to a `Double`. If this fails, something is
      // wrong with the lexing process.
      guard let floatingPointValue = Double(trimmedBuffer) else {
        fatalError("Lexer Error: Was not able to convert `String`(" +
          numberBuffer + ") to `Double`.\n")
      }
      token = .floatingPoint(floatingPointValue)
    } else {
      // Tries to convert the literal to an `Int`. If this fails, something is
      // wrong with the lexing process.
      guard let integerValue = Int(trimmedBuffer, radix: radix) else {
        fatalError("Lexer Error: Was not able to convert `String`(" +
                    numberBuffer + ") to `Int`.\n")
      }
      token = .integer(integerValue)
    }

    return token
  }

  /// Detects character literals.
  ///
  /// - Note: Characters are delimited with single-quotes.
  ///
  /// - Returns: A `.character` token if a character literal was detected,
  /// otherwise `nil`.
  static func forCharacters(_ buffer: inout Character, _ lexer: LiteralLexer)
  -> Token? {
    guard buffer == "'" else { return nil }
    buffer = lexer.nextCharacter()

    guard buffer != "'" else {
      fatalError("Lexer Error: Expected a character between two `'`.\n")
    }
    let character = buffer
    buffer = lexer.nextCharacter()

    guard buffer == "'" else {
      fatalError("Lexer Error: Expected only one character between two `'`.\n")
    }
    buffer = lexer.nextCharacter()

    return .character(character)
  }

  /// Detects uninterpolated string literals.
  ///
  /// - Note: Strings are delimited with double-quotes.
  ///
  /// - Returns: An `.uninterpolatedString` token if such a string literal was
  /// detected, otherwise `nil`.
  static func forUninterpolatedStrings(
    _ buffer: inout Character,
    _ lexer: LiteralLexer
  ) -> Token? {
    guard buffer == "\"" else { return nil }
    buffer = lexer.nextCharacter()

    var stringBuffer = ""

    while buffer != "\"" {
      guard buffer != lexer.endOfFile else {
        fatalError("Lexer Error: Expected closing `\"`.\n")
      }
      stringBuffer.append(buffer)
      buffer = lexer.nextCharacter()
    }

    buffer = lexer.nextCharacter()

    return .uninterpolatedString(stringBuffer)
  }

  /// Detects flag literals.
  ///
  /// - Note: Flags are identifiers (any combination of alphanumeric characters
  /// starting with a letter) prefixed by a `-`.
  ///
  /// - Returns: A `.flag` token if a flag literal was detected, otherwise
  /// `nil`.
  static func forFlags(_ buffer: inout Character, _ lexer: LiteralLexer)
  -> Token? {
    guard buffer == "-" else { return nil }
    guard lexer.nextCharacter(peek: true).isPart(of: .letters) else {
      return nil
    }
    buffer = lexer.nextCharacter()

    var flagBuffer = ""

    repeat {
      flagBuffer.append(buffer)
      buffer = lexer.nextCharacter()
    } while buffer.isPart(of: .alphanumerics)

    return .flag(flagBuffer)
  }
}
