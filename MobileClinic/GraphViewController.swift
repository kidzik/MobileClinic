//
//  GraphViewController.swift
//  MobileClinic
//
//  Created by Sreehari Ram Mohan on 12/8/18.
//  Copyright © 2018 tpomac2017. All rights reserved.
//

import Foundation
import Charts

class GraphViewController: UIViewController {
    

    
    var rawNumericEntries = [CGFloat](); //data passed from segue
    var numSquats: Int!
    var angleEntries =  [ChartDataEntry]();
    
    @IBOutlet weak var chart: LineChartView!
    @IBOutlet weak var SquatCount: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        SquatCount.text = "\(numSquats!) Squats"
        
        var i: Double = 0;
        for float in rawNumericEntries {
            var entry = ChartDataEntry(x: i, y: Double(float))
            i = i+1;
            
            angleEntries.append(entry);
        }
        
        graphData();
        
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
    }
    
    func graphData() {
        let angleCurve = LineChartDataSet(values: angleEntries, label: "Angles");
        
        angleCurve.colors = [NSUIColor.blue];
        
        let data = LineChartData();
        
        data.addDataSet(angleCurve);
    
        chart.data = data;
        
        chart.chartDescription?.text = "Angle Time Series"
    }
    
    
}
