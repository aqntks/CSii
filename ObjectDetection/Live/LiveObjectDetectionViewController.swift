import AVFoundation
import Foundation
import UIKit

class LiveObjectDetectionViewController: ViewController {
    @IBOutlet var cameraView: CameraPreviewView!
    @IBOutlet var benchmarkLabel: UILabel!
    @IBOutlet var indicator: UIActivityIndicatorView!
    @IBOutlet weak var guideLabel: UILabel!
    @IBOutlet weak var modeChangeBtn: UIButton!
    
    private let delayMs: Double = 1000
    private var prevTimestampMs: Double = 0.0
    private var cameraController = CameraController()
    private var imageViewLive =  UIImageView()

    private var inferencer = ObjectDetector()
    private var cardResult: String!
    private var sendCheck: Bool = false
    
    private var cardNumber: String!
    private var cardMonth: String!
    private var cardYear: String!
    
    //테스트
//    var backLayer: CALayer!
//    var maskLayerColor: UIColor = UIColor.black
//    var maskLayerAlpha: CGFloat = 0.7
    var verticalMode: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.isNavigationBarHidden = true
        
        cameraController.configPreviewLayer(cameraView)
        
        imageViewLive.frame = CGRect(x: 0, y: 0, width: cameraView.frame.size.width, height: cameraView.frame.size.height)
        cameraView.addSubview(imageViewLive)
        
        // 촬영 모드 설정 및 버튼 적용
        setupCardGuide(mode: "horizontal")
        modeChangeBtn.setTitle("세로카드 스캔", for: .normal)
        modeChangeBtn.setImage(#imageLiteral(resourceName: "bt_ic_card"), for: .normal)
        modeChangeBtn.setTitleColor(.black, for: .normal)
        modeChangeBtn.imageView?.contentMode = .scaleAspectFit
        modeChangeBtn.titleLabel?.font = .boldSystemFont(ofSize: 18)
        modeChangeBtn.contentHorizontalAlignment = .center
        modeChangeBtn.semanticContentAttribute = .forceLeftToRight
        modeChangeBtn.imageEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: 0)
        
        
        cameraController.videoCaptureCompletionBlock = { [weak self] buffer, error in
            guard let strongSelf = self else { return }
            if error != nil {
                return
            }
            guard var pixelBuffer = buffer else { return }

            let currentTimestamp = CACurrentMediaTime()
            if (currentTimestamp - strongSelf.prevTimestampMs) * 1000 <= strongSelf.delayMs { return }
            strongSelf.prevTimestampMs = currentTimestamp
//            let startTime = CACurrentMediaTime()
            guard let outputs = self?.inferencer.module.detect(image: &pixelBuffer) else {
                return
            }
//            let inferenceTime = CACurrentMediaTime() - startTime
            DispatchQueue.main.async {
                let ivScaleX : Double =  Double(strongSelf.imageViewLive.frame.size.width / CGFloat(PrePostProcessor.inputWidth))
                let ivScaleY : Double = Double(strongSelf.imageViewLive.frame.size.height / CGFloat(PrePostProcessor.inputHeight))

                let startX = Double((strongSelf.imageViewLive.frame.size.width - CGFloat(ivScaleX) * CGFloat(PrePostProcessor.inputWidth))/2)
                let startY = Double((strongSelf.imageViewLive.frame.size.height -  CGFloat(ivScaleY) * CGFloat(PrePostProcessor.inputHeight))/2)
                
                let nmsPredictions = PrePostProcessor.outputsToNMSPredictions(outputs: outputs, imgScaleX: 1.0, imgScaleY: 1.0, ivScaleX: ivScaleX, ivScaleY: ivScaleY, startX: startX, startY: startY)

                PrePostProcessor.cleanDetection(imageView: strongSelf.imageViewLive)
                strongSelf.indicator.isHidden = true
                strongSelf.benchmarkLabel.isHidden = false
                strongSelf.benchmarkLabel.text = "complete"
                
                PrePostProcessor.showDetection(imageView: strongSelf.imageViewLive, nmsPredictions: nmsPredictions, classes: strongSelf.inferencer.classes)
               // guard !(self?.createMRZ(predictions: nmsPredictions))! else { return }
                
                
//                let (text, value) = self!.sortCard(predictions: nmsPredictions)
                
                let (text, _) = self!.new_sortCard(predictions: nmsPredictions)
                self?.cardResult = text
                
                if self!.cardResult.count > 23 && self!.sendCheck == false && text != "실패"{
                    self!.performSegue(withIdentifier: "showResult", sender: self)
                    self!.sendCheck = true
                }
            }
        }
    }
    
    
    private func new_sortCard(predictions: [Prediction]) -> (resultText: String, score: Float){
        var index: Int = 0
        var score: Float = 0
        var resultText: String = ""
        var number: Prediction!
        var date: Prediction!
        var numberValue: String = ""
        var dateValue: String = ""
        
        
        let sortXPrediction = predictions.sorted{$0.rect.origin.x < $1.rect.origin.x}
        
        for cls in sortXPrediction {
            if cls.classIndex == 11 {
                number = cls
            }
            else if cls.classIndex == 12 {
                date = cls
            }
            else {continue}
        }
        
      
        // 검출 실패 시 코드 작성
        if number == nil || date == nil {
            print("영역 검출 실패")
            return ("실패", 0)
        }
        
        for cls in sortXPrediction {
            if cls.rect.minY > number.rect.minY && cls.rect.maxY < number.rect.maxY && cls.rect.minX > number.rect.minX && cls.rect.maxX < number.rect.maxX {
                numberValue.append(self.inferencer.classes[cls.classIndex])
                score = score + cls.score
                index = index + 1
            }
            else if cls.rect.minY > date.rect.minY && cls.rect.maxY < date.rect.maxY && cls.rect.minX > date.rect.minX && cls.rect.maxX < date.rect.maxX {
                dateValue.append(self.inferencer.classes[cls.classIndex])
                score = score + cls.score
                index = index + 1
            }
            else {continue}
        }
        
        // 검출 실패 시 코드 작성
        if numberValue.count != 16 || dateValue.count != 5 {
            print("박스 내 갯수 부족")
            return ("실패", 0)
        }
        

        // 결과 저장
        cardNumber = numberValue
        cardMonth = String(dateValue[...dateValue.index(dateValue.startIndex, offsetBy: 1)])
        cardYear = String(dateValue[dateValue.index(dateValue.startIndex, offsetBy: 3)...])
        
        if Int(cardMonth)! > 12 || Int(cardMonth)! < 1 {
            print("month 값 오류")
            return ("실패", 0)
        }
        if Int(cardYear)! > 50 || Int(cardYear)! < 10 {
            print("year 값 오류")
            return ("실패", 0)
        }

        var countNumber: Int = 1
        var numberResult: String = ""
        for s in numberValue{
            numberResult.append(s)
            if countNumber % 4 == 0 {numberResult.append(" ")}
            countNumber = countNumber + 1
        }
        
        resultText.append(numberResult)
        resultText.append("\n")
        resultText.append(dateValue)
        
        print(resultText)
        
        return (resultText, score/Float(index))
    }
    
    func cardValid() {
        
    }
    
    
    // 세로모드 카드 가이드 설정
    func setupCardGuide(mode: String) {
        //뒷배경 색깔 및 투명도
        let maskLayerColor: UIColor = UIColor.white
        let maskLayerAlpha: CGFloat = 1.0
        var cardBoxLocationX: CGFloat!
        var cardBoxLocationY: CGFloat!
        var cardBoxWidthSize: CGFloat!
        var cardBoxheightSize: CGFloat!
        
        ////////////// 영역 설정
        if mode == "horizontal" {
            // 카드 가이드 박스 가로 사이즈 = 전체 영역 94%
            cardBoxWidthSize = view.bounds.width * 0.94
            // 카드 가이드 박스 세로 사이즈 = 전체 영역 40%
            cardBoxheightSize = cardBoxWidthSize / 1.58
            // 카드 가이드 박스 시작 X 좌표 = 전체 뷰 영역의 3% 위치
            cardBoxLocationX = view.bounds.width * 0.03
            // 카드 가이드 박스 시작 Y 좌표 = 전체 뷰 영역의 25% 위치
            cardBoxLocationY = view.bounds.height * 0.25
        }
        else {
            // 카드 가이드 박스 세로 사이즈 = 전체 영역 40%
            cardBoxheightSize = modeChangeBtn.frame.minY - guideLabel.frame.maxY - 60
            // 카드 가이드 박스 가로 사이즈 = 전체 영역 94%
            cardBoxWidthSize = cardBoxheightSize / 1.58
            // 카드 가이드 박스 시작 X 좌표 = 전체 뷰 영역의 3% 위치
            cardBoxLocationX = (view.bounds.width - cardBoxWidthSize) / 2
            // 카드 가이드 박스 시작 Y 좌표 = 전체 뷰 영역의 25% 위치
            cardBoxLocationY = guideLabel.frame.maxY + 30
        }
        
        let cardRect = CGRect(x: cardBoxLocationX,
                                y: cardBoxLocationY,
                                width: cardBoxWidthSize,
                                height: cardBoxheightSize)

        // 카드 가이드 백그라운드 설정
        let backLayer = CALayer()
        backLayer.frame = view.bounds
        backLayer.backgroundColor = maskLayerColor.withAlphaComponent(maskLayerAlpha).cgColor

        // 카드 가이드 구역 설정
        let maskLayer = CAShapeLayer()
        let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 10.0)
        path.append(UIBezierPath(rect: view.bounds))
        maskLayer.path = path.cgPath
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        backLayer.mask = maskLayer
        self.cameraView.layer.addSublayer(backLayer)
        
        self.cameraView.bringSubviewToFront(modeChangeBtn)
        self.cameraView.bringSubviewToFront(guideLabel)
    }
    
    // 가로 세로 모드 변경
    @IBAction func change(_ sender: Any) {
        cameraView.layer.sublayers?.remove(at: cameraView.layer.sublayers!.count - 3)
        
        // 세로로 변경
        if verticalMode == true {
            verticalMode=false
            setupCardGuide(mode: "vertical")
            modeChangeBtn.setTitle("가로카드 스캔", for: .normal)
            
        }
        // 가로로 변경
        else {
            verticalMode=true
            setupCardGuide(mode: "horizontal")
            modeChangeBtn.setTitle("세로카드 스캔", for: .normal)
    
        }
    }
    
   
    //결과 페이지에 값 전송
    override func prepare(for segue: UIStoryboardSegue, sender: Any?){
        if segue.destination is ResultController{
            let newController = segue.destination as? ResultController
            newController?.cardNumber = self.cardNumber
            newController?.cardMonth = self.cardMonth
            newController?.cardYear = self.cardYear
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
        cameraController.startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraController.stopSession()
    }

    @IBAction func onBackClicked(_: Any) {
        navigationController?.popViewController(animated: true)
    }
}
