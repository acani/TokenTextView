import UIKit

open class InsetLabel: UILabel {
  open var textInsets = UIEdgeInsets.zero

  open override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
    let insetRect = bounds.inset(by: textInsets)
    var textRect = super.textRect(forBounds: insetRect, limitedToNumberOfLines: numberOfLines)
    // Do the opposite of UIEdgeInsetsInsetRect(textRect, textInsets)
    textRect.origin.x -= textInsets.left
    textRect.origin.y -= textInsets.top
    textRect.size.width += textInsets.left + textInsets.right
    textRect.size.height += textInsets.top + textInsets.bottom
    return textRect
  }

  open override func drawText(in rect: CGRect) {
    let fullRect = textRect(forBounds: rect, limitedToNumberOfLines: numberOfLines)
    let insetRect = fullRect.inset(by: textInsets)
    super.drawText(in: insetRect)
  }
}
