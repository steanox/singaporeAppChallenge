//
//  StartViewController.swift
//  Singapore App Challenge
//
//  Created by Octavianus Gandajaya on 10/7/17.
//  Copyright © 2017 Octavianus Gandajaya. All rights reserved.
//

import UIKit

class StartViewController: UIViewController {

    @IBOutlet weak var imageCircle: UIImageView!
    @IBOutlet weak var cameraButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    

    @IBAction func startMeasure(sender: UIButton){
        UIView.animate(withDuration: 0.3) {[weak self] in
            self?.cameraButton.transform = CGAffineTransform.init(scaleX: 1.2, y: 1.2)
        }
        
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 3, initialSpringVelocity: 0, options: [], animations: {[weak self] in
            self?.imageCircle.transform = CGAffineTransform.init(rotationAngle: 90)
        }) { [weak self] (status) in
            if status{
                self?.performSegue(withIdentifier: "showObject", sender: nil)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let dest = segue.destination as! ChooseObjectViewController
        dest.previous = self
    }

}

