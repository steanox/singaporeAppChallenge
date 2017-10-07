//
//  HistoryCell.swift
//  Singapore App Challenge
//
//  Created by Octavianus Gandajaya on 10/7/17.
//  Copyright © 2017 Octavianus Gandajaya. All rights reserved.
//

import UIKit

enum StatusState{
    case approved
    case waiting
    case rejected
}

class HistoryCell: UITableViewCell {

    var stuff: Stuff?{
        didSet{
            mainImage.image = UIImage(named: (stuff?.mainImage)!)
            
            if stuff?.status == .approved{
                    statusImage.image = UIImage(named: "approved")
            }else
            if stuff?.status == .waiting{
                    statusImage.image = UIImage(named: "waiting")
            }else
            if stuff?.status == .approved{
                    statusImage.image = UIImage(named: "reject")
            }
            
            self.date.text = stuff?.dates
            self.hours.text = stuff?.hours
            
            
        }
        
    }
    
    
    @IBOutlet weak var mainImage: UIImageView!
    @IBOutlet weak var statusImage: UIImageView!
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var hours: UILabel!
    
    

}
