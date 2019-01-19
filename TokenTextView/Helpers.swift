import Foundation

extension String {
  public var length: Int { return utf16.distance(from: utf16.startIndex, to: utf16.endIndex) }

  public func index(at location: Int) -> String.Index {
    let index = utf16.index(utf16.startIndex, offsetBy: location)
    return index.samePosition(in: self)!
  }

  public func location(at index: String.Index) -> Int {
    let utf16Index = index.samePosition(in: utf16)!
    return utf16.distance(from: utf16.startIndex, to: utf16Index)
  }
}

extension NSMutableAttributedString {
  open func append(_ string: String) {
    let endNSRange = NSRange(location: length, length: 0)
    replaceCharacters(in: endNSRange, with: string)
  }
}

// Source: http://stackoverflow.com/a/33674192/242933
extension Collection {
  func binarySearch(_ predicate: (Iterator.Element) -> Bool) -> Index {
    var low = startIndex
    var high = endIndex
    while low != high {
      let mid = index(low, offsetBy: distance(from: low, to: high)/2)
      if predicate(self[mid]) {
        low = index(after: mid)
      } else {
        high = mid
      }
    }
    return low
  }
}
