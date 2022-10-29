//
//  ViewController.swift
//  SwiftTest01
//
//  Created by 沈栩烽 on 10/29/22.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var textNumber1: UITextField!

    @IBOutlet weak var textNumber2: UITextField!

    @IBOutlet weak var resultLabel: UILabel!

    @IBAction func calculate(_ sender: UIButton) {
        let num1 = Int(textNumber1.text!)!
        let num2 = Int(textNumber2.text!)!
        let sum = num1+num2
        resultLabel.text = String(sum)
    }

}

