//
//  TrialViewController.swift
//  BoneDetecter
//
//  Created by vedran on 19/11/2018.
//  Copyright © 2018 tpomac2017. All rights reserved.
//

import UIKit

class TrialViewController: UIViewController {

// one random frame from the recorded video used in Trial view
    @IBOutlet weak var randomImageView: UIImageView!

    @IBOutlet weak var score: UILabelStroked!
    @IBOutlet weak var status: UILabelStroked!
    
    var activityID: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let activityID = activityID {
            
            let row = session.activities[activityID]
            
            score.text = NSNumber(integerLiteral: row.score).stringValue
            status.text = row.status
            
            randomImageView.image = row.sampleImage
        }

    }

}
