//
//  ConfirmTableViewCell.swift
//  eziwallet
//
//  Created by Mark Macpherson on 7/7/17.
//  Copyright © 2017 Pay Your Bills. All rights reserved.
//

import UIKit

protocol ConfirmCellDelegate: class {
    func didSelectConfirm(for cell: ConfirmTableViewCell)
}

class ConfirmTableViewCell: UITableViewCell {
    
    @IBOutlet weak var stepLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    @IBOutlet weak var confirmButton: UIButton!
    @IBAction func confirmButtonAction(_ sender: UIButton) {
        delegate?.didSelectConfirm(for: self)
    }
    
    weak var delegate: ConfirmCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func configure(enabled: Bool, type: EziWalletTransactionType) {
        self.backgroundColor = tableViewCellBackgroundColor()
        self.selectionStyle = .none
        
        var titleText = ""
        var descriptionText = ""
        var stepText = ""
        
        switch type {
        case .topup:
            titleText = Constants.ConfirmTopUpText
            descriptionText = Constants.ConfirmTopUpDescriptionText
            stepText = Constants.Step4Text
        case .withdraw:
            titleText = Constants.ConfirmWithdrawText
            descriptionText = Constants.ConfirmWithdrawDescriptionText
            stepText = Constants.Step5Text
        case .transfer:
            titleText = Constants.ConfirmTransferText
            descriptionText = Constants.ConfirmTransferDescriptionText
            stepText = Constants.Step5Text
        }
        
        self.stepLabel.text = stepText
        self.descriptionLabel.text = descriptionText
        
        self.confirmButton.setTitle(titleText, for: UIControlState())
        self.confirmButton.layer.cornerRadius = Constants.ImageViewLayerCornerRadius
        self.confirmButton.clipsToBounds = true
        self.confirmButton.isEnabled = enabled
        
        if enabled {
            self.confirmButton.backgroundColor = systemColor().withAlphaComponent(1.0)
            self.confirmButton.tintColor = UIColor.white
        } else {
            self.confirmButton.backgroundColor = systemColor().withAlphaComponent(0.3)
            self.confirmButton.tintColor = systemDarkGrayColor()
        }
        
    }

}
