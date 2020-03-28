import UIKit

@objc public protocol TokenTextViewDelegate: NSObjectProtocol {
  func updateMatches(for tokenTextView: TokenTextView)
  func tokenTextView(_ tokenTextView: TokenTextView, tableViewCellForRowAt indexPath: IndexPath) -> UITableViewCell
  @objc optional func tokenTextViewDidChange(_ tokenTextView: TokenTextView)
  @objc optional func tokenTextViewDidShowTableView(_ tokenTextView: TokenTextView)
  @objc optional func tokenTextViewDidHideTableView(_ tokenTextView: TokenTextView)
  @objc optional func sanitizedInputText(for tokenTextView: TokenTextView) -> String
  @objc optional func tokenTextView(_ tokenTextView: TokenTextView, titleForValue value: Any) -> String
  @objc optional func tokenTextViewDidTokenizeInputText(_ tokenTextView: TokenTextView)
  @objc optional func tokenTextViewDidTokenizeMatch(_ tokenTextView: TokenTextView)
  @objc optional func tokenTextView(_ tokenTextView: TokenTextView, didRemoveTokenAt index: Int)
  @objc optional func tokenTextViewDidReturn(_ tokenTextView: TokenTextView)
}

open class TokenTextView: UITextView, UITextViewDelegate, UITableViewDataSource, UITableViewDelegate {
  weak open var tokenDelegate: TokenTextViewDelegate?
  open var inputText: String { String(text![inputTextRange]) }
  open var matches: [Any]?
  open var values = [Any]()
  open var collapsedLabel = InsetLabel(frame: .zero)
  open var tableView: UITableView?

  public init(frame: CGRect, textContainer: NSTextContainer?, prefix: String) {
    self.prefix = prefix
    collapsedLabel.adjustsFontForContentSizeCategory = true
    collapsedLabel.isUserInteractionEnabled = true
    super.init(frame: frame, textContainer: textContainer)
    autocorrectionType = .no
    adjustsFontForContentSizeCategory = true
    attributedText = attributedPrefixAndSpace
    clipsToBounds = false
    delegate = self
    isScrollEnabled = false
    keyboardType = .emailAddress
    self.textContainer.heightTracksTextView = true // What does this do?
    textDragInteraction?.isEnabled = false
    let tapGestureRecognizer = UITapGestureRecognizer(
      target: self,
      action: #selector(tapCollapsedLabelAction)
    )
    collapsedLabel.addGestureRecognizer(tapGestureRecognizer)
  }

  // MARK: - NSCoding

  required public init?(coder: NSCoder) {
    fatalError("init(coder:) hasn't been implemented")
  }

  open func initMatchesAndTableView() -> UITableView {
    matches = []
    tableView = UITableView(frame: .zero, style: .plain)
    tableView!.dataSource = self
    tableView!.delegate = self
    tableView!.isHidden = true
    tableView!.keyboardDismissMode = .interactive
    tableView!.preservesSuperviewLayoutMargins = true
    return tableView!
  }

  open func appendValue(_ value: Any) {
    values.append(value)
    let title = tokenDelegate!.tokenTextView!(self, titleForValue: value)
    appendToken(withTitle: title)
  }

  open func removeValue(at index: Int) {
    let range = rangeOfToken(at: index)
    let nsrange = NSRange(range, in: text)
    removeToken(at: index)
    textStorage.deleteCharacters(in: nsrange)
  }

  open func collapse() {
    isHidden = true
    let nsrange = NSRange(location: 0, length: attributedText.length-2)
    let attributedTextBeforeLastComma =
      attributedText.attributedSubstring(from: nsrange)
    collapsedLabel.attributedText = attributedTextBeforeLastComma
    collapsedLabel.isHidden = false
    superview!.setNeedsLayout() // if just disimissed keyboard interactively
  }

  // MARK: - UIResponder

  open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if selectedTokenIndex != nil { return false }
    return super.canPerformAction(action, withSender: sender)
  }

  // MARK: - UITextView

  override open var selectionHighlightColor: UIColor {
    let color = super.selectionHighlightColor // in case super has side effects
    return selectedTokenIndex == nil ? color : .clear
  }

  // MARK: - UITextViewDelegate

  open func textView(_ textView: UITextView, shouldChangeTextIn nsrange: NSRange, replacementText: String) -> Bool {
    if replacementText == "\n" {
      if inputTextRange.isEmpty {
        tokenDelegate?.tokenTextViewDidReturn?(self)
      } else {
        tokenizeInputText()
      }
      return false
    }
    let isDeleteOrCut = replacementText.isEmpty
    if selectedTokenIndex == nil {
      if isDeleteOrCut {
        if nsrange.length == 1 && nsrange.location == newTokenStartLocation {
          if tokenCount > 0 { selectToken(at: tokenCount-1) }
          return false
        }
      }
    } else {
      let index = selectedTokenIndex!
      removeToken(at: index)
      selectedTokenIndex = nil
      if isDeleteOrCut {
        textStorage.deleteCharacters(in: nsrange)
      } else {
        textStorage.beginEditing()
        textStorage.deleteCharacters(in: nsrange)
        textStorage.append(replacementText)
        textStorage.endEditing()
        updateTableView()
      }
      moveCursorToEndOfText()
      tokenDelegate?.tokenTextView?(self, didRemoveTokenAt: index)
      tokenDelegate?.tokenTextViewDidChange?(self)
      return false
    }
    shouldIgnoreSelectionChange = true
    return true
  }

  open func textViewDidChange(_ textView: UITextView) {
    updateTableView()
    tokenDelegate?.tokenTextViewDidChange?(self)
  }

  open func textViewDidChangeSelection(_ textView: UITextView) {
    if shouldIgnoreSelectionChange {
      shouldIgnoreSelectionChange = false
      return
    }
    if let index = indexOfToken(at: selectedRange.location) {
      selectToken(at: index)
      return
    }
    if selectedTokenIndex != nil { deselectToken() }
    if selectedRange.location <= newTokenStartLocation {
      shouldIgnoreSelectionChange = true
      selectedRange = NSRange(location: newTokenStartLocation+1, length: selectedRange.length)
    }
  }

  open func textViewDidEndEditing(_ textView: UITextView) {
    if selectedTokenIndex != nil {
      deselectToken()
      moveCursorToEndOfText()
    }
    if !inputTextRange.isEmpty { tokenizeInputText() }
    if tokenCount > 0 { collapse() }
  }

  // MARK: - UITableViewDataSource

  open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    matches!.count
  }

  open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    tokenDelegate!.tokenTextView(self, tableViewCellForRowAt: indexPath)
  }

  // MARK: - UITableViewDelegate

  open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let match = matches![indexPath.row]
    appendValue(match)
    tokenDelegate?.tokenTextViewDidTokenizeMatch?(self)
    tokenDelegate?.tokenTextViewDidChange?(self)
  }

  // MARK: - Helpers

  private let prefix: String
  private var tokenEndIndices: [String.Index] = []
  private var selectedTokenIndex: Int?
  private var shouldIgnoreSelectionChange = false
  private var tokenCount: Int { tokenEndIndices.count }
  private var firstTokenStartIndex: String.Index {
    text.index(text.startIndex, offsetBy: prefix.count)
  }
  private var newTokenStartIndex: String.Index {
    tokenEndIndices.last ?? firstTokenStartIndex
  }
  private var newTokenStartLocation: Int {
    text.location(at: newTokenStartIndex)
  }
  private var inputTextRange: Range<String.Index> {
    let inputTextStartIndex = text.index(after: newTokenStartIndex)
    return Range(uncheckedBounds: (inputTextStartIndex, text.endIndex))
  }

  private func appendToken(withTitle title: String) {
    let range = Range(uncheckedBounds: (newTokenStartIndex, text.endIndex))
    let nsrange = NSRange(range, in: text)
    let attributedString = tokenAttributedString(with: title)
    attributedString.append(attributedSpace)
    textStorage.replaceCharacters(in: nsrange, with: attributedString)
    let newLastTokenEndIndex = text.index(before: text.endIndex)
    tokenEndIndices.append(newLastTokenEndIndex)
    if selectedTokenIndex != nil { deselectToken() }
    moveCursorToEndOfText()
    hideTableView()
  }

  private func removeToken(at index: Int) {
    values.remove(at: index)
    if index == tokenCount-1 {
      tokenEndIndices.remove(at: index)
    } else {
      let prefix = tokenEndIndices.prefix(upTo: index)
      let start = tokenStartIndex(at: index)
      let distance = -text.distance(from: start, to: tokenEndIndices[index])
      let suffix = tokenEndIndices.suffix(from: index+1).lazy.map {
        self.text.index($0, offsetBy: distance)
      }
      tokenEndIndices = Array(prefix) + suffix
    }
  }

  private func tokenizeInputText() {
    let title = tokenDelegate?.sanitizedInputText?(for: self) ?? inputText
    var tokenAlreadyExists: Bool {
      values.contains() { value -> Bool in
        guard let value = (value as? String) else { return false }
        return value.caseInsensitiveCompare(title) == .orderedSame
      }
    }
    if title.isEmpty || tokenAlreadyExists {
      clearInputText()
    } else {
      values.append(title)
      appendToken(withTitle: title)
      tokenDelegate?.tokenTextViewDidTokenizeInputText?(self)
    }
    tokenDelegate?.tokenTextViewDidChange?(self)
  }

  private func clearInputText() {
    let nsrange = NSRange(inputTextRange, in: text)
    textStorage.deleteCharacters(in: nsrange)
    if selectedTokenIndex != nil {
      deselectToken()
      moveCursorToEndOfText()
    }
    hideTableView()
  }

  private func moveCursorToEndOfText() {
    shouldIgnoreSelectionChange = true
    selectedRange = NSRange(location: text.length, length: 0)
  }

  private func updateTableView() {
    guard let tableView = tableView else { return }
    tokenDelegate!.updateMatches(for: self)
    tableView.reloadData() // clears cells preventing crash if matches!.isEmpty
    if matches!.isEmpty {
      hideTableView()
    } else {
      showTableView()
    }
  }

  private func selectToken(at index: Int) {
    if index == selectedTokenIndex { return }
    shouldIgnoreSelectionChange = true
    let range = rangeOfToken(at: index)
    let nsrange = NSRange(range, in: text)
    selectedRange = nsrange
    if selectedTokenIndex != nil { unhighlightSelectedToken() }
    selectedTokenIndex = index
    highlightSelectedToken()
  }

  private func deselectToken() {
    unhighlightSelectedToken()
    selectedTokenIndex = nil
  }

  private func indexOfToken(at location: Int) -> Int? {
    guard let lastTokenEndIndex = tokenEndIndices.last else { return nil }
    let index = text.index(at: location)
    if index >= lastTokenEndIndex { return nil }
    return tokenEndIndices.binarySearch { $0 <= index }
  }

  private func rangeOfToken(at index: Int) -> Range<String.Index> {
    Range(uncheckedBounds: (tokenStartIndex(at: index), tokenEndIndices[index]))
  }

  private func tokenStartIndex(at index: Int) -> String.Index {
    index == 0 ? firstTokenStartIndex : tokenEndIndices[index-1]
  }

  // MARK: - Styling

  private var fontAttributes: [NSAttributedString.Key: Any] {
    [.font: UIFont.preferredFont(forTextStyle: .body)]
  }

  private var attributedSpace: NSAttributedString {
    NSAttributedString(string: " ", attributes: fontAttributes)
  }

  private var attributedPrefixAndSpace: NSAttributedString {
    var attributes = fontAttributes
    attributes[.foregroundColor] =
      UIColor(red: 142/255, green: 142/255, blue: 147/255, alpha: 1)
    let attributedString =
      NSMutableAttributedString(string: prefix, attributes: attributes)
    attributedString.append(attributedSpace)
    return attributedString
  }

  private func tokenAttributedString(with title: String) -> NSMutableAttributedString {
    let attributedString = NSMutableAttributedString(string: " \(title),")
    let nsrange = NSRange(location: 0, length: attributedString.length)
    addUnhighlightedTokenAttributes(to: attributedString, in: nsrange)
    return attributedString
  }

  private func highlightSelectedToken() {
    var attributes = fontAttributes
    let darkBlueColor = UIColor(red: 20/255, green: 106/255, blue: 1, alpha: 1)
    attributes[.backgroundColor] = darkBlueColor
    let nsranges = tokenNSRanges(from: selectedRange)
    textStorage.beginEditing()
    textStorage.setAttributes(attributes, range: nsranges.space)
    attributes[.foregroundColor] = UIColor.white
    textStorage.setAttributes(attributes, range: nsranges.title)
    attributes[.foregroundColor] = darkBlueColor
    textStorage.setAttributes(attributes, range: nsranges.comma)
    textStorage.endEditing()
  }

  private func unhighlightSelectedToken() {
    let range = rangeOfToken(at: selectedTokenIndex!)
    let nsrange = NSRange(range, in: text)
    addUnhighlightedTokenAttributes(to: textStorage, in: nsrange)
  }

  private func addUnhighlightedTokenAttributes(to attributedString: NSMutableAttributedString, in nsrange: NSRange) {
    var attributes = fontAttributes
    let nsranges = tokenNSRanges(from: nsrange)
    attributedString.beginEditing()
    attributedString.setAttributes(attributes, range: nsranges.space)
    attributes[.foregroundColor] =
      UIColor(red: 0, green: 0.478431, blue: 1, alpha: 1) // blue
    attributedString.setAttributes(attributes, range: nsranges.title)
    attributes[.foregroundColor] = UIColor(white: 128/255, alpha: 1.0)
    attributedString.setAttributes(attributes, range: nsranges.comma)
    attributedString.endEditing()
  }

  private func tokenNSRanges(from nsrange: NSRange) -> (space: NSRange, title: NSRange, comma: NSRange) {
    let location = nsrange.location
    let spaceNSRange = NSRange(location: location, length: 1)
    let titleNSRange = NSRange(location: location+1, length: nsrange.length-2)
    let commaNSRange = NSRange(location: location+nsrange.length-1, length: 1)
    return (space: spaceNSRange, title: titleNSRange, comma: commaNSRange)
  }

  private func showTableView() {
    if !tableView!.isHidden { return }
    tableView!.isHidden = false
    tableView!.flashScrollIndicators()
    tokenDelegate!.tokenTextViewDidShowTableView!(self)
  }

  private func hideTableView() {
    if tableView!.isHidden { return }
    tableView!.isHidden = true
    tokenDelegate!.tokenTextViewDidHideTableView!(self)
  }

  @objc private func tapCollapsedLabelAction(recognizer: UITapGestureRecognizer) {
    collapsedLabel.isHidden = true
    isHidden = false
    becomeFirstResponder()
  }
}
