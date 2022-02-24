//
//  StatusViewController.swift
//  PC Building
//
//  Created by Irene Lee on 2022-01-08.
//

import Foundation
import ARKit

class InstructionsViewController: UIViewController {
    
    @IBOutlet weak var messagePanel: UIVisualEffectView!
    
    @IBOutlet weak var messageLabel: UILabel!


    // MARK: - Message Handling
    private var messageHideTimer: Timer?
    /// Seconds before the timer message should fade out. Adjust if the app needs longer transient messages.
    private let displayDuration: TimeInterval = 1000
    
    func showMessage(_ text: String, autoHide: Bool = true) {
        // Cancel any previous hide timer.
        messageHideTimer?.invalidate()

        messageLabel.text = text

        // Make sure status is showing.
        setMessageHidden(false, animated: true)

        if autoHide {
            messageHideTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false, block: { [weak self] _ in
                self?.setMessageHidden(true, animated: true)
            })
        }
    }
    
    private func setMessageHidden(_ hide: Bool, animated: Bool) {
        // The panel starts out hidden, so show it before animating opacity.
        messagePanel.isHidden = false
        
        guard animated else {
            messagePanel.alpha = hide ? 0 : 1
            return
        }

        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState], animations: {
            self.messagePanel.alpha = hide ? 0 : 1
        }, completion: nil)
    }
    
    
    
    
}
