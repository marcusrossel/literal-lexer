//
//  Lexer Frame.swift
//  Lexer Frame
//
//  Created by Marcus Rossel on 26.08.16.
//  Copyright © 2016 Marcus Rossel. All rights reserved.
//

import Foundation

/// A non-consuming, generic, configurable lexer frame.
public final class Lexer<Token> {
  /// The character that signifies that the end of `text` is reached.
  ///
  /// - Note: This character is used to circumvent the need to return an
  /// optional from `nextCharacter()`.
  public var endOfFile: Character = "\0"

  /// The plain text, which will be lexed.
  public var text: String

  /// Used to keep track of the current relevant character in `text`.
  public var position = 0

  /// A token-transform that might produce a token or could fail.
  public typealias PossibleTransform = (
    _ buffer: inout Character,
    _ lexer: Lexer
  ) -> Token?

  /// A token-transform that is guaranteed to produce a token.
  public typealias GuaranteedTransform = (
    _ buffer: inout Character,
    _ lexer: Lexer
  ) -> Token

  /// A sequence of token-generating transforms, which will be called in order
  /// in `nextToken()`.
  ///
  /// - Note: These transforms are inteded to perform the pattern matching,
  /// aswell. If it fails `nil` can therefore be returned.
  public var tokenTransforms: [PossibleTransform]

  /// A default guaranteed token-generating transform which is called when all
  /// other `tokenTransforms` fail.
  public var defaultTransform: GuaranteedTransform

  /// The initialization of a `Lexer` requires at least a `defaultTransform`.
  init(
    text: String = "",
    defaultTransform: @escaping GuaranteedTransform,
    tokenTransforms: [PossibleTransform] = []
  ) {
    self.text = text
    self.defaultTransform = defaultTransform
    self.tokenTransforms = tokenTransforms
  }

  /// Returns the the next character in `text`.
  ///
  /// - Note: If `position` has reached `text`'s maximum index, it's considered
  /// consumed and `endOfFile` is returned.
  ///
  /// ```
  /// Detailed Example:
  /// text: "abc"
  ///
  /// (1)
  /// position = 0
  /// *call*
  /// positionWillBeInBounds = 0 + 1 - 1 < 3 := true
  /// guard true
  /// return text[0 + 1 - 1 := 0] := "a"
  /// defer if true && true -> position += 1
  ///
  /// (2)
  /// position = 1
  /// *call*
  /// positionWillBeInBounds = 1 + 1 - 1 < 3 := true
  /// guard true
  /// return text[1 + 1 - 1 := 1] := "b"
  /// defer if true && true -> position += 1
  ///
  /// (3)
  /// position = 2
  /// *call*
  /// positionWillBeInBounds = 2 + 1 - 1 < 3 := true
  /// guard true
  /// return text[2 + 1 - 1 := 2] := "c"
  /// defer if true && true -> position += 1
  ///
  /// (4)
  /// position = 3
  /// *call*
  /// positionWillBeInBounds = 3 + 1 - 1 < 3 := false
  /// guard false -> return endOfFile
  /// defer if true && false
  ///
  /// repeat (4)
  /// ```
  ///
  /// - Parameter peek: Determines whether or not the character that's being
  /// returned is consumed or not.
  /// - Parameter stride: The offset from the current `position` that the
  /// character to be returned is at. When `peek` is `false` this consumes all
  /// of the characters in range of the `offset`.
  func nextCharacter(peek: Bool = false, stride: Int = 1) -> Character {
    guard stride >= 1 else {
      fatalError("Lexer Error: \(#function): `stride` must be >= 1.\n")
    }

    let nextCharacterIndex = position + stride - 1

    defer {
      if !peek && nextCharacterIndex <= text.characters.count {
        position += stride
      }
    }
    guard nextCharacterIndex < text.characters.count else { return endOfFile }

    return text[text.index(text.startIndex, offsetBy: position + stride - 1)]
  }

  /// Returns the next `Token` according to the following system:
  ///
  /// 1. Stores next character in a buffer.
  /// 2. Sequentially calls the `tokenTransforms`.
  /// 3. If one of the `tokenTransforms` succeeds it's `Token` is returned, and
  /// the remaining buffer character is restored.
  /// 4. If all `tokenTransforms` return `nil` the `defaultTransform`'s return
  /// value is returned.
  func nextToken() -> Token {
    var buffer = nextCharacter()

    for transform in tokenTransforms {
      if let token = transform(&buffer, self) {
        defer { position -= 1 }
        return token
      }
    }

    return defaultTransform(&buffer, self)
  }
}
