//
//  ConfirmTransactionViewController.swift
//  eziwallet
//
//  Created by Mark Macpherson on 11/7/17.
//  Copyright © 2017 Pay Your Bills. All rights reserved.
//

import UIKit


protocol ConfirmTransactionViewDelegate: class {
    func confirmTransactionViewDidCompleteTransaction(_ confirmTransactionView: ConfirmTransactionViewController)
    func confirmTransactionViewDidCancel(_ confirmTransactionView: ConfirmTransactionViewController)
}

class ConfirmTransactionViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var titleContainerView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var closeButton: UIButton!
    @IBAction func closeButtonAction(_ sender: UIButton) {
        close()
    }
    
    @IBOutlet weak var confirmTransactionButton: UIButton!
    @IBAction func confirmTransactionButtonAction(_ sender: UIButton) {
        performTransaction()
    }
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var activityIndicatorContainerView: UIView!
    
    
    weak var delegate: ConfirmTransactionViewDelegate?
    
    var transaction: Transaction? // Will be set on segue
    var processingTransaction = false
    
    // var transactionType: EziWalletTransactionType = .topup // A default, will be set on segue
    
    
    fileprivate struct Storyboard {
        static let TableViewEstimatedRowHeight: CGFloat = 50.0
        
        static let CardDetailsDisplayCellReuseIdentifier = "CardDetailsDisplayCellReuseIdentifier"
        static let RecipientDisplayCellReuseIdentifier = "RecipientDisplayCellReuseIdentifier"
        static let FeesChargesDisplayCellReuseIdentifier = "FeesChargesDisplayCellReuseIdentifier"
        static let SingleButtonCellReuseIdentifier = "SingleButtonCellReuseIdentifier"
        static let ExchangeRateAndTotalCellReuseIdentifier = "ExchangeRateAndTotalCellReuseIdentifier"
        
        static let UnwindFromConfirmTransactionSegueIdentifier = "UnwindFromConfirmTransactionSegueIdentifier"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        titleContainerView.backgroundColor = systemColor()
        titleLabel.attributedText = NSAttributedString(string: Constants.ConfirmText, attributes: navigationBarTitleTextAttributes())
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = Storyboard.TableViewEstimatedRowHeight
        tableView.backgroundColor = tableViewBackgroundColor()
        
        hideActivityIndicator() // Just in case...
        activityIndicator.color = systemColor()
        activityIndicatorContainerView.backgroundColor = .white
        activityIndicatorContainerView.isHidden = true
        activityIndicatorContainerView.layer.cornerRadius = Constants.ImageViewLayerCornerRadius
        activityIndicatorContainerView.clipsToBounds = true
        
        confirmTransactionButton.setTitleColor(UIColor.white, for: .normal)
        
        guard let type = transaction?.type else {
            // Can't get there
            confirmTransactionButton.setTitle(Constants.TransferNowText, for: .normal)
            return
        }
        
        switch type {
        case .topup:
            confirmTransactionButton.setTitle(Constants.TopUpNowText, for: .normal)
        case .withdraw:
            confirmTransactionButton.setTitle(Constants.WithdrawNowText, for: .normal)
        case .transfer:
            confirmTransactionButton.setTitle(Constants.TransferNowText, for: .normal)
        }
        
        updateUI()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Init/Setup methods
    
    
    // MARK: - UI Methods
    
    fileprivate func updateUI() {
        // Don't reload the tableview here. Use reloadData() for that.
        if processingTransaction {
            self.confirmTransactionButton.isEnabled = false
        } else {
            self.confirmTransactionButton.isEnabled = true
        }
    }
    
    func reloadData() {
        // Not private, may need to be called from the tabBarController, for example
        self.tableView.reloadData()
    }
    
    func showActivityIndicator() {
        self.activityIndicator.startAnimating()
        self.activityIndicatorContainerView.isHidden = false
    }
    
    func hideActivityIndicator() {
        self.activityIndicator.stopAnimating()
        self.activityIndicatorContainerView.isHidden = true
    }
    
    // MARK: - Action methods
    
    func close() {
        delegate?.confirmTransactionViewDidCancel(self)
    }
    
    
    // MARK: - Gesture methods
    
    
    // MARK: - Navigation
    

}

// MARK: - Extension - UITableViewDataSource

extension ConfirmTransactionViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let type = transaction?.type else {
            // Can't get here
            return 4
        }
        
        switch type {
        case .topup:
            return 4
        case .withdraw:
            return 4
        case .transfer:
            return 4
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = systemColor()
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let type = transaction?.type else {
            return transferCellForRowAt(indexPath)
        }
        
        switch type {
        case .topup:
            return topUpCellForRowAt(indexPath)
        case .withdraw:
            return withdrawCellForRowAt(indexPath)
        case .transfer:
            return transferCellForRowAt(indexPath)
        }
    }
    
    //------------------------------------------
    // Cells for the different transaction types
    
    func topUpCellForRowAt(_ indexPath: IndexPath) -> UITableViewCell {
        guard let transaction = self.transaction,
            // let eziWallet = transaction.eziWallet,
            let nameOnCard = transaction.paymentMethod?.nameOnCard,
            let cardNumber = transaction.paymentMethod?.cardNumber,
            let expiry = transaction.paymentMethod?.cardExpiry else {
                let cell = tableView.dequeueReusableCell(withIdentifier: Constants.SingleLabelCellReuseIdentifier, for: indexPath) as! SingleLabelTableViewCell
                cell.configure(with: "")
                return cell
        }
        
        let amount = transaction.amount
        
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: Constants.SingleLabelCellReuseIdentifier, for: indexPath) as! SingleLabelTableViewCell
            let text = "\(Constants.YouWillTopUpText) \(Constants.WithText) \(transaction.currency.code.rawValue) \(amount.format(places: 2))"
            cell.configure(with: text)
            return cell
        } else if indexPath.row == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.CardDetailsDisplayCellReuseIdentifier, for: indexPath) as! CardDetailsDisplayTableViewCell
            cell.configure(description: Constants.FromTheCardText, cardNumber: cardNumber, nameOnCard: nameOnCard, expiry: expiry)
            return cell
        } else if indexPath.row == 2 {
            let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.FeesChargesDisplayCellReuseIdentifier, for: indexPath) as! FeesChargesDisplayTableViewCell
            cell.configure(feesAndCharges: transaction.feesAndCharges, currency: transaction.currency, amount: amount)
            return cell
        }
        
        // Confirm button
        let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.SingleButtonCellReuseIdentifier, for: indexPath) as! SingleButtonTableViewCell
        cell.configure(using: Constants.TopUpNowText)
        cell.delegate = self
        return cell
    }
    
    func withdrawCellForRowAt(_ indexPath: IndexPath) -> UITableViewCell {
        guard let transaction = self.transaction,
            // let eziWallet = transaction.eziWallet,
            let nameOnCard = transaction.paymentMethod?.nameOnCard,
            let cardNumber = transaction.paymentMethod?.cardNumber,
            let expiry = transaction.paymentMethod?.cardExpiry else {
                let cell = tableView.dequeueReusableCell(withIdentifier: Constants.SingleLabelCellReuseIdentifier, for: indexPath) as! SingleLabelTableViewCell
                cell.configure(with: "")
                return cell
        }
        
        let amount = transaction.amount
        
        var youReceiveAmount = amount
        if let feesAndCharges = transaction.feesAndCharges, feesAndCharges.includeFeesCharges {
            youReceiveAmount -= (feesAndCharges.fees + feesAndCharges.charges)
        }
        
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: Constants.SingleLabelCellReuseIdentifier, for: indexPath) as! SingleLabelTableViewCell
            let text = "\(Constants.YouWillWithdrawText) \(transaction.currency.code.rawValue) \(youReceiveAmount.format(places: 2))"
            cell.configure(with: text)
            return cell
        } else if indexPath.row == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.CardDetailsDisplayCellReuseIdentifier, for: indexPath) as! CardDetailsDisplayTableViewCell
            cell.configure(description: Constants.ToTheCardText, cardNumber: cardNumber, nameOnCard: nameOnCard, expiry: expiry)
            return cell
        } else if indexPath.row == 2 {
            let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.FeesChargesDisplayCellReuseIdentifier, for: indexPath) as! FeesChargesDisplayTableViewCell
            cell.configure(feesAndCharges: transaction.feesAndCharges, currency: transaction.currency, amount: amount)
            return cell
        }
        
        // Confirm button
        let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.SingleButtonCellReuseIdentifier, for: indexPath) as! SingleButtonTableViewCell
        cell.configure(using: Constants.WithdrawNowText)
        cell.delegate = self
        return cell
    }
    
    func transferCellForRowAt(_ indexPath: IndexPath) -> UITableViewCell {
        guard let transaction = self.transaction,
            // let eziWallet = transaction.eziWallet,
            let recipient = transaction.recipient,
            recipient.isValid else {
                let cell = tableView.dequeueReusableCell(withIdentifier: Constants.SingleLabelCellReuseIdentifier, for: indexPath) as! SingleLabelTableViewCell
                cell.configure(with: "")
                return cell
        }
        
        let amount = transaction.amount
        
        var recipientReceivesAmount = amount
        if let feesAndCharges = transaction.feesAndCharges, feesAndCharges.includeFeesCharges {
            recipientReceivesAmount -= (feesAndCharges.fees + feesAndCharges.charges)
        }
        
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: Constants.SingleLabelCellReuseIdentifier, for: indexPath) as! SingleLabelTableViewCell
            let text = "\(Constants.YouWillTransferTheEquivalentText) \(transaction.currency.code.rawValue) \(recipientReceivesAmount.format(places: 2))"
            cell.configure(with: text)
            return cell
        } else if indexPath.row == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.RecipientDisplayCellReuseIdentifier, for: indexPath) as! RecipientDisplayTableViewCell
            cell.configure(with: recipient, description: Constants.ToText)
            return cell
        } else if indexPath.row == 2 {
            let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.FeesChargesDisplayCellReuseIdentifier, for: indexPath) as! FeesChargesDisplayTableViewCell
            cell.configure(feesAndCharges: transaction.feesAndCharges, currency: transaction.currency, amount: amount)
            return cell
        }
        
        // Confirm button
        let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.SingleButtonCellReuseIdentifier, for: indexPath) as! SingleButtonTableViewCell
        cell.configure(using: Constants.TransferNowText)
        cell.delegate = self
        return cell
    }
    
    
    //------------------------------------------
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    }
    
}

// MARK: - Extension - UITableViewDelegate

extension ConfirmTransactionViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
    }
}

// MARK: - Extension - SingleButtonCellDelegate

extension ConfirmTransactionViewController: SingleButtonCellDelegate {
    
    func didSelectButtonAction(for cell: SingleButtonTableViewCell) {
        performTransaction()
    }
    
}


// MARK: - Extension - Data retrieval/Server methods

extension ConfirmTransactionViewController {
    
    func performTransaction() {
        
        guard let transaction = self.transaction else {
            return
        }
        
        self.processingTransaction = true
        showActivityIndicator()
        updateUI()
        
        if transaction.type == .transfer {
            TransactionService.transfer(transaction) { [weak self] (response, data) in
                guard let strongSelf = self else { return }
                printLog("transfer() call completed")
                strongSelf.processingTransaction = false
                DispatchQueue.main.async {
                    strongSelf.hideActivityIndicator()
                }
                
                if response.status == .success {
                    if let responseData = Transaction.transactionFrom(serverResponseData: data) {
                        let transaction = responseData
                        printLog("transfer() return == success")
                        strongSelf.transaction = transaction
                    } else {
                        // Successful return but no data.
                        printLog("transfer() return but no data. ")
                    }
                    
                    DispatchQueue.main.async {
                        let title = Constants.TransferText
                        let message = Constants.TransferTransactionCompletedText
                        showOKAlert(title: title, message: message, presentingViewController: strongSelf) { (action) in
                            strongSelf.delegate?.confirmTransactionViewDidCompleteTransaction(strongSelf)
                        }
                    }
                } else {
                    // Error
                    DispatchQueue.main.async {
                        TransactionService.processServerError(response, presentingViewController: strongSelf)
                    }
                }
            }
        } else if transaction.type == .topup {
            TransactionService.topup(transaction) { [weak self] (response, data) in
                guard let strongSelf = self else { return }
                printLog("topup() call completed")
                strongSelf.processingTransaction = false
                DispatchQueue.main.async {
                    strongSelf.hideActivityIndicator()
                }
                
                if response.status == .success {
                    if let responseData = Transaction.transactionFrom(serverResponseData: data) {
                        let transaction = responseData
                        printLog("topup() return == success")
                        strongSelf.transaction = transaction
                    } else {
                        // Successful return but no data.
                        printLog("topup() return but no data. ")
                    }
                    
                    DispatchQueue.main.async {
                        let title = Constants.TopUpText
                        let message = Constants.TopupTransactionCompletedText
                        showOKAlert(title: title, message: message, presentingViewController: strongSelf) { (action) in
                            strongSelf.delegate?.confirmTransactionViewDidCompleteTransaction(strongSelf)
                        }
                    }
                } else {
                    // Error
                    DispatchQueue.main.async {
                        TransactionService.processServerError(response, presentingViewController: strongSelf)
                    }
                }
            }
        } else if transaction.type == .withdraw {
            TransactionService.topup(transaction) { [weak self] (response, data) in
                guard let strongSelf = self else { return }
                printLog("withdraw() call completed")
                strongSelf.processingTransaction = false
                DispatchQueue.main.async {
                    strongSelf.hideActivityIndicator()
                }
                
                if response.status == .success {
                    if let responseData = Transaction.transactionFrom(serverResponseData: data) {
                        let transaction = responseData
                        printLog("withdraw() return == success")
                        strongSelf.transaction = transaction
                    } else {
                        // Successful return but no data.
                        printLog("withdraw() return but no data. ")
                    }
                    
                    DispatchQueue.main.async {
                        let title = Constants.WithdrawText
                        let message = Constants.WithdrawTransactionCompletedText
                        showOKAlert(title: title, message: message, presentingViewController: strongSelf) { (action) in
                            strongSelf.delegate?.confirmTransactionViewDidCompleteTransaction(strongSelf)
                        }
                    }
                } else {
                    // Error
                    DispatchQueue.main.async {
                        TransactionService.processServerError(response, presentingViewController: strongSelf)
                    }
                }
            }
        }
    }
}

