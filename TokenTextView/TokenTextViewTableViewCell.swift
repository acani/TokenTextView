import UIKit

open class TokenTextViewTableViewCell: UITableViewCell {
  public let titleLabel = UILabel(frame: .zero)
  public let subtitleLabel = UILabel(frame: .zero)

  // MARK: - UITableViewCell

  override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)

    titleLabel.adjustsFontForContentSizeCategory = true
    titleLabel.font = .preferredFont(forTextStyle: .body)
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(titleLabel)

    subtitleLabel.adjustsFontForContentSizeCategory = true
    subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
    subtitleLabel.textColor = UIColor(red: 136/255, green: 136/255, blue: 139/255, alpha: 1)
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(subtitleLabel)

    let margins = contentView.layoutMarginsGuide
    NSLayoutConstraint.activate([
      titleLabel.topAnchor.constraint(equalTo: margins.topAnchor),
      titleLabel.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
      titleLabel.trailingAnchor.constraint(equalTo: margins.trailingAnchor),

      subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor),
      subtitleLabel.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
      subtitleLabel.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
      subtitleLabel.trailingAnchor.constraint(equalTo: margins.trailingAnchor)
    ])
  }

  // MARK: - NSCoding

  required public init?(coder: NSCoder) { fatalError("init(coder:) hasn't been implemented") }
}
