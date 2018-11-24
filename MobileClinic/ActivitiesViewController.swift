//
//  ActivitiesViewController.swift
//  BoneDetecter
//
//  Created by vedran on 19/11/2018.
//  Copyright © 2018 tpomac2017. All rights reserved.
//

import UIKit

class ActivitiesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var list: UITableView!
    
    @IBAction func didPressRecord(_ sender: Any) {

        let presentingViewController = self.presentingViewController
        
        self.dismiss(animated: true) {
            DispatchQueue.main.async {
                
                presentingViewController?.dismiss(animated: true) {
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return session.activities.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ActivityTableViewCell
        
        let row = session.activities[indexPath.row]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        cell.date.text = dateFormatter.string(from: row.date)
        
        cell.score.text = "\(row.score)/100"
//        NSNumber(integerLiteral: row.score).stringValue

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if let presentingViewController = self.presentingViewController as? TrialViewController {
            print("didSelectRowAt \(presentingViewController)")
            presentingViewController.activityID = indexPath.row
            self.dismiss(animated: true) {
            }
        }
    }
}
