//
//  ConvoTableViewCell.swift
//  Schmooze
//
//  Created by MAD2 on 8/2/22.
//

import UIKit


class ConvoTableViewCell: UITableViewCell {
    
    static let identifier = "ConvoTableViewCell"

    
    private let userNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 21, weight: .semibold)
        return label
    }()

    private let userMessageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 19, weight: .regular)
        label.numberOfLines = 0
        return label
    }()
  
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(userNameLabel)
        contentView.addSubview(userMessageLabel)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        userNameLabel.frame = CGRect(x: 10,
                                     y: 10,
                                     width: 150,
                                     height: 80)
        
        userMessageLabel.frame = CGRect(x: userNameLabel.right + 30,
                                     y: 20,
                                     width: contentView.width - 5 - userNameLabel.width,
                                     height: (contentView.height)/2)
    
        
    }
    
    public func configure(with model: Conversation) {
        self.userMessageLabel.text = model.latestMessage.text
        self.userNameLabel.text = model.name
    }

    

}
