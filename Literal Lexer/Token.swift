//
//  Token.swift
//  Literal Lexer
//
//  Created by Marcus Rossel on 11.08.16.
//  Copyright © 2016 Marcus Rossel. All rights reserved.
//

import Foundation

/// The literals that can be lexed by the `literalLexer`. 
enum Token {
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
}

/// A namespace for all of the token transforms.
///
/// All of the methods are of the form: `Lexer.PossibleTransform`.
///
/// The parameter `buffer` is the current relevant character and is passed in by
/// `lexer.nextToken()`.
/// When the function returns, `buffer` should be set to the next relevant
/// character.
enum TokenTransform {
  /// Detects and ignores consecutive whitespaces.
  ///
  /// - Returns: `nil`
  static func forWhitespaces(_ buffer: inout Character, _ lexer: Lexer<Token>) -> Token? {
    while buffer.isPart(of: .whitespaces) {
      buffer = lexer.nextCharacter()
    }
    return nil
  }

  /// Detects the `Lexer.endOfFile` character (`"\0"`).
  ///
  /// - Returns: `.endOfLine` if the respective character was detected,
  /// otherwise `nil`.
  static func forEndOfFile(_ buffer: inout Character, _ lexer: Lexer<Token>) -> Token? {
    guard buffer == lexer.endOfFile else { return nil }

    buffer = lexer.nextCharacter()
    return .endOfFile
  }

  /// Detects newline characters.
  ///
  /// - Returns: `.newLine` if the respective character was detected,
  /// otherwise `nil`.
  static func forNewLines(_ buffer: inout Character, _ lexer: Lexer<Token>) -> Token? {
    guard buffer.isPart(of: .newlines) else { return nil }

    buffer = lexer.nextCharacter()
    return .newLine
  }

  /// Detects and returns the contents of open (`//`) and closed (`/**/`)
  /// comments.
  /// Open comments end with the end of `Lexer.text` and can therefore only be
  /// used after all other tokens have appeared.
  ///
  /// - Returns: A `.whitespace` token if a comment was detected, otherwise
  /// `nil`.
  static func forComments(_ buffer: inout Character, _ lexer: Lexer<Token>) -> Token? {
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
    } /* Handles closed comments. */ else if lexer.nextCharacter(peek: true) == "*" {
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
  static func forBooleans(_ buffer: inout Character, _ lexer: Lexer<Token>) -> Token? {
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

  /// Detects floating-point literals.
  ///
  /// - Returns: A `.floatingPoint` token if a floating-point literal was
  /// detected, otherwise `nil`.
  static func forFloatingPoints(_ buffer: inout Character, _ lexer: Lexer<Token>) -> Token? {
    // A backup of the current state of `buffer` and `lexer.position`, which can
    // be restored, incase the characters turn out not to form a floating-point
    // literal.
    let backup = (buffer: buffer, position: lexer.position)

    guard let floatingPointIsNegative = numberIsNegative(buffer: &buffer, lexer: lexer) else {
      return nil
    }

    var floatingPointBuffer = floatingPointIsNegative ? "-" : ""

    // Gets all of the characters that belong to the literal and stores them in
    // `floatingPointBuffer`.
    repeat {
      floatingPointBuffer.append(buffer)
      buffer = lexer.nextCharacter()
    } while buffer.isPart(of: .decimalDigits) ||
      buffer == "_" ||
      (buffer == "." && !floatingPointBuffer.contains("."))

    // Makes sure that the `floatingPointBuffer` actually contains a decimal
    // point (otherwise it should be lexed as an integer) and that it's not the
    // last character.
    // It can't be the first one anyway, as `numberIsNegative` doesn't allow
    // that.
    guard
      floatingPointBuffer.contains("."),
      floatingPointBuffer.characters.last != "."
    else {
      buffer = backup.buffer
      lexer.position = backup.position
      return nil
    }

    // Removes underscores from the floating-point literal.
    let trimmedBuffer = floatingPointBuffer.replacingOccurrences(of: "_", with: "")
    // Tries to convert the literal to a double. If this fails, something is
    // wrong with the lexing process.
    guard let floatingPointValue = Double(trimmedBuffer) else {
      fatalError("Lexer Error: Was not able to convert `String`(" +
        floatingPointBuffer + ") to `Double`.\n")
    }

    return .floatingPoint(floatingPointValue)
  }

  /// Detects binary, octal, decimal and hexadecimal integer literals.
  /// The different types are denoted by prefixes:
  /// * binary: `0b`
  /// * octal: `0o`
  /// * decimal: no prefix
  /// * hexadecimal: `0h`
  ///
  /// - Returns: An `.integer` token if an integer literal was detected,
  /// otherwise `nil`.
  static func forIntegers(_ buffer: inout Character, _ lexer: Lexer<Token>) -> Token? {
    guard let integerIsNegative = numberIsNegative(buffer: &buffer, lexer: lexer) else {
      return nil
    }

    // Assumes that the integer literal will be decimal.
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

        // Only if the first character after `0b`, `0o` or `0x` is valid, the
        // integer literal can be valid.
        let postPrefix = String(lexer.nextCharacter(peek: true, stride: 2))
        guard validCharacters.contains(postPrefix) else { break nonDecimals }
        buffer = lexer.nextCharacter(stride: 2)
      }
    }

    var integerBuffer = integerIsNegative ? "-" : ""

    // Gets all of the characters that belong to the literal and stores them in
    // `integerBuffer`.
    repeat {
      integerBuffer.append(buffer)
      buffer = lexer.nextCharacter()
    } while validCharacters.contains(String(buffer))

    // Removes underscores from the integer literal.
    let trimmedBuffer = integerBuffer.replacingOccurrences(of: "_", with: "")
    // Tries to convert the literal to an integer. If this fails, something is
    // wrong with the lexing process.
    guard let integerValue = Int(trimmedBuffer, radix: radix) else {
      fatalError("Lexer Error: Was not able to convert `String`(" +
        integerBuffer + ") to `Int`.\n")
    }
    
    return .integer(integerValue)
  }

  /// A convenience method used in `forIntegers` and `forFloatingPoints`.
  ///
  /// Indicates whether a given number will be negative or not.
  ///
  /// - Precondition: `buffer` holds the current relevant character.
  /// - Postcondition: `buffer` is still the same, or holds the first character
  /// after the sign-symbol, if a number will be constructable.
  ///
  /// - Returns: An optional `Bool` that is `true` if the number is negative,
  /// `false` if it is not, and `nil` if no number will be constructable from
  /// the given character sequence.
  private static func numberIsNegative(buffer: inout Character, lexer: Lexer<Token>) -> Bool? {
    let numberIsNegative = buffer == "-"
    let testBuffer = numberIsNegative ? lexer.nextCharacter(peek: true) : buffer

    guard testBuffer.isPart(of: .decimalDigits) else { return nil }
    if numberIsNegative { buffer = lexer.nextCharacter() }

    return numberIsNegative
  }

  /*UNFINISHED-START*/
  static func forNumbers(_ buffer: inout Character, _ lexer: Lexer<Token>) -> Token? {
    // Determines if the number is negative, and if the first character after
    // the sign-character even qualifies for a number.
    let numberIsNegative = buffer == "-"
    let testBuffer = numberIsNegative ? lexer.nextCharacter(peek: true) : buffer

    guard testBuffer.isPart(of: .decimalDigits) else { return nil }
    if numberIsNegative { buffer = lexer.nextCharacter() }


  }
  /*UNFINISHED-END*/

  /// Detects character literals.
  ///
  /// - Note: Characters are delimited with single-quotes.
  ///
  /// - Returns: A `.character` token if a character literal was detected,
  /// otherwise `nil`.
  static func forCharacters(_ buffer: inout Character, _ lexer: Lexer<Token>) -> Token? {
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
  static func forUninterpolatedStrings(_ buffer: inout Character, _ lexer: Lexer<Token>) -> Token? {
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
  static func forFlags(_ buffer: inout Character, _ lexer: Lexer<Token>) -> Token? {
    guard buffer == "-" else { return nil }
    guard lexer.nextCharacter(peek: true).isPart(of: .letters) else { return nil }
    buffer = lexer.nextCharacter()

    var flagBuffer = ""

    repeat {
      flagBuffer.append(buffer)
      buffer = lexer.nextCharacter()
    } while buffer.isPart(of: .alphanumerics)

    return .flag(flagBuffer)
  }
}
