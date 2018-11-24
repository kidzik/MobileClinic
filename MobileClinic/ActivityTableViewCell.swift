//
//  ActivityTableViewCell.swift
//  BoneDetecter
//
//  Created by vedran on 20/11/2018.
//  Copyright © 2018 tpomac2017. All rights reserved.
//

import UIKit

class ActivityTableViewCell: UITableViewCell {

    @IBOutlet weak var date: UILabelStroked!
    @IBOutlet weak var score: UILabelStroked!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
