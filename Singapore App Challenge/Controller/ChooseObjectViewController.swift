//
//  ChooseObjectViewController.swift
//  Singapore App Challenge
//
//  Created by Octavianus Gandajaya on 10/7/17.
//  Copyright © 2017 Octavianus Gandajaya. All rights reserved.
//

import UIKit

class ChooseObjectViewController: UIViewController {
    
    var previous: StartViewController?
    
    @IBOutlet weak var sphereRightConstraint: NSLayoutConstraint!
    @IBOutlet weak var triangleRightConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sphereRightConstraint.constant = 90
        triangleRightConstraint.constant = 90
        
        UIView.animate(withDuration: 0.5, delay: 0.3, usingSpringWithDamping: 8, initialSpringVelocity: 0, options: [], animations: {
            [weak self] in
            self?.view.layoutIfNeeded()
        }, completion: nil)
        
    }

    @IBAction func back(sender: UIButton){
        previous?.imageCircle.transform = CGAffineTransform.identity
        dismiss(animated: true, completion: nil)
    }
    

}
