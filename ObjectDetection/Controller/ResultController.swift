
import Foundation
import UIKit

class ResultController: UIViewController, UINavigationControllerDelegate, UITextFieldDelegate {

    
    @IBOutlet var cardNumberField: UITextField!
    @IBOutlet weak var expireLabel: UILabel!
    
    @IBOutlet weak var expireTextField: UITextField!
    var cardNumber: String!
    var cardMonth: String!
    var cardYear: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.isNavigationBarHidden = false
        self.navigationController?.navigationBar.backItem?.backBarButtonItem?.accessibilityElementsHidden = true
        
        
//
//        let width = cardNumberField.bounds.width / 2
//        let height = cardNumberField.bounds.height
//        let startX = cardNumberField.bounds.minX
//        let startY = cardNumberField.bounds.maxY + 100
//
//        expireTextField = UITextField(frame: CGRect(x: startX , y: startY, width: width, height: height))
//        expireTextField.delegate = self
//        expireTextField.borderStyle = .roundedRect
//        self.view.addSubview(expireTextField)
        setResult()
    }
    
    // UI 필드에 결과 값 적용
    func setResult() {
        var countNumber: Int = 1
        var numberResult: String = ""
        for s in cardNumber{
            numberResult.append(s)
            if countNumber % 4 == 0 {numberResult.append(" ")}
            countNumber = countNumber + 1
        }
        
        cardNumberField.text = numberResult.trimmingCharacters(in: .whitespaces)
        expireTextField.text = cardMonth + "/" + cardYear
    }

    @IBAction func backMain(_ sender: Any) {
        self.navigationController?.isNavigationBarHidden = true
        self.navigationController?.popToRootViewController(animated: true)
    }

}

