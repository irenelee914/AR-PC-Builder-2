//
//  Popup.swift
//  PC Building
//
//  Created by Irene Lee on 2021-12-01.
//

import UIKit

class Popup: UIView {
    
    var viewController:ViewController
    
    fileprivate let titleLabel: UILabel = {
        let label = PaddingLabel(withInsets: 0, 8, 18, 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.contentMode = .scaleToFill
        label.numberOfLines = 0
        label.text = "Welcome, to the PC Builder App!"
        label.textAlignment = .center
        return label
    }()
    
    
    fileprivate let subtitleLabel: UILabel = {
        let label = PaddingLabel(withInsets: 0, 8, 18, 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.text = "How would you like to get started?"
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    fileprivate let container: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .white
        v.layer.cornerRadius = 24
        return v
    }()
    
    fileprivate let identifyPCPartsButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 5
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.clear.cgColor
        button.setTitle("Identify PC Parts", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.addTarget(self, action: #selector(identifyPCPartsButtonClicked), for: .touchUpInside)
        return button
    }()
    
    fileprivate let startPCBuildingButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 0, height: 15))
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 5
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.clear.cgColor
        button.setTitle("Start Building PC", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.addTarget(self, action: #selector(startPCBuildingButtonClicked), for: .touchUpInside)
        return button
    }()
    
    @objc func startPCBuildingButtonClicked() {
        print("startPCBuildingButtonClicked")
        animateOut()
        self.viewController.detectionOverlay.isHidden = true
        self.viewController.menuButton.isHidden = true
        self.viewController.previousButton.isHidden = false
        self.viewController.nextButton.isHidden = false
        self.viewController.stateController.step = 1
        self.viewController.updateARView()
    }
    
    @objc func identifyPCPartsButtonClicked() {
        print("identifyPCPartsButtonClicked")
        animateOut()
        self.viewController.detectionOverlay.isHidden = false
        self.viewController.statusViewController.showMessage("IDENTIFY PC PARTS")
        self.viewController.menuButton.isHidden = false
    }
    
    fileprivate lazy var identifyPCPartsButtonStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [identifyPCPartsButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = UIStackView.spacingUseSystem
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 10, right: 10)
        return stack
    }()
    
    fileprivate lazy var startPCBuildingButtonStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [startPCBuildingButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = UIStackView.spacingUseSystem
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 10)
        return stack
    }()
    
    
    fileprivate lazy var stack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, identifyPCPartsButtonStack, startPCBuildingButtonStack])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        return stack
    }()
    
    @objc fileprivate func animateOut() {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1, options: .curveEaseIn, animations: {
            self.container.transform = CGAffineTransform(translationX: 0, y: -self.frame.height)
            self.alpha = 0
        }) { (complete) in
            if complete {
                self.removeFromSuperview()
            }
        }
    }
    
    @objc fileprivate func animateIn() {
        self.container.transform = CGAffineTransform(translationX: 0, y: -self.frame.height)
        self.alpha = 1
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1, options: .curveEaseIn, animations: {
            self.container.transform = .identity
            self.alpha = 1
        })
    }
    
    init(frame: CGRect, viewController:ViewController) {
        self.viewController = viewController
        super.init(frame: frame)
        
//        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(animateOut)))
        self.backgroundColor = UIColor.gray.withAlphaComponent(0.6)
        self.frame = UIScreen.main.bounds
        self.addSubview(container)
      
        container.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        container.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        container.widthAnchor.constraint(equalTo: self.widthAnchor, multiplier: 0.7).isActive = true
        container.heightAnchor.constraint(equalTo: self.heightAnchor, multiplier: 0.45).isActive = true
        
        container.addSubview(stack)
        stack.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
        stack.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true
        stack.centerYAnchor.constraint(equalTo: container.centerYAnchor).isActive = true
        stack.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.7).isActive = true
        
        animateIn()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class PaddingLabel: UILabel {
    
    var topInset: CGFloat
    var bottomInset: CGFloat
    var leftInset: CGFloat
    var rightInset: CGFloat
    
    required init(withInsets top: CGFloat, _ bottom: CGFloat, _ left: CGFloat, _ right: CGFloat) {
        self.topInset = top
        self.bottomInset = bottom
        self.leftInset = left
        self.rightInset = right
        super.init(frame: CGRect.zero)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
        super.drawText(in: rect.inset(by: insets))
    }
    
    override var intrinsicContentSize: CGSize {
        get {
            var contentSize = super.intrinsicContentSize
            contentSize.height += topInset + bottomInset
            contentSize.width += leftInset + rightInset
            return contentSize
        }
    }
    
}

