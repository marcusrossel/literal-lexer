//
//  Extensions.swift
//  Literal Lexer
//
//  Created by Marcus Rossel on 11.08.16.
//  Copyright © 2016 Marcus Rossel. All rights reserved.
//

import Foundation

internal extension String {
  subscript(offset offset: Int) -> Character {
    return self[index(startIndex, offsetBy: offset)]
  }
}

internal extension Character {
  func isPart(of set: CharacterSet) -> Bool {
    return String(self).rangeOfCharacter(from: set) != nil
  }
}
