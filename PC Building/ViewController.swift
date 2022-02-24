//
//  ViewController.swift
//  PC Building
//
//  Created by Irene Lee on 2021-11-02.
//

import UIKit
import RealityKit
import ARKit
import Vision

class ViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet var arView: ARView!
    var notificationTrigger: RAM.NotificationTrigger!
    var stateController: StateController!
    var textInstructions:UILabel!
    
    /// Vision request for the detection model
    private var requests = [VNRequest]()
    /// Layer used to host detectionOverlay layer
    var rootLayer: CALayer! = nil
    /// The detection overlay layer used to render bounding boxes
    var detectionOverlay: CALayer! = nil
    /// Whether the current frame should be skipped (in terms of model predictions)
    var shouldSkipFrame = 0
    /// How often (in terms of camera frames) should the app run predictions
    let predictEvery = 3
    var lastOrientation: CGImagePropertyOrientation = .right
    var bufferSize: CGSize = .zero
    
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    
    let predictionQueue = DispatchQueue(label: "predictionQueue",
                                        qos: .userInitiated,
                                        attributes: [],
                                        autoreleaseFrequency: .inherit,
                                        target: nil)
    

    lazy var statusViewController: InstructionsViewController = {
        return children.lazy.compactMap({ $0 as? InstructionsViewController }).first!
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // --- Hide Buttons ---
        self.previousButton.isHidden = true
        self.nextButton.isHidden = true
        self.menuButton.isHidden = true
        
        
        // --- PopUP View: Gives user 2 options ----
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            let pop = Popup(frame: CGRect(), viewController: self)
                    self.view.addSubview(pop)
        }
        
        arView.session.delegate = self
        rootLayer = arView.layer
        
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
        do {
            try  videoDevice!.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice?.activeFormat.formatDescription)!)
            print(dimensions)
            print(arView.frame)
//            bufferSize.width = CGFloat(dimensions.width)
//            bufferSize.height = CGFloat(dimensions.height)
            bufferSize.width = CGFloat(arView.frame.width)
            bufferSize.height = CGFloat(arView.frame.height)
//            bufferSize.width = 640.0
//            bufferSize.height = 480.0
            videoDevice!.unlockForConfiguration()
        }
        catch {
            print(error)
        }
        setupLayers()
        
        guard let modelURL = Bundle.main.url(forResource: "FullNetwork", withExtension: "mlmodelc") else {
            print("ERROR")
            return
        }
        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            let objectRecognition = VNCoreMLRequest(model: visionModel, completionHandler: { (request, error) in
                DispatchQueue.main.async(execute: {
                    // perform all the UI updates on the main queue
                    if let results = request.results {
//                        print(results)
                        self.drawVisionRequestResults(results)
                    }
                })
            })
            self.requests = [objectRecognition]
        } catch let error as NSError {
            print("Model loading went wrong: \(error)")
        }
//        diceDetectionRequest.imageCropAndScaleOption = .scaleFill
        
        stateController = StateController()
        updateARView()
    }
    
    func setupLayers() {
        self.detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        self.detectionOverlay.name = "DetectionOverlay"
        self.detectionOverlay.bounds = CGRect(x: 0.0,
                                              y: 0.0,
                                              width: bufferSize.width,
                                              height: bufferSize.height)
        self.detectionOverlay.position = CGPoint(x: self.rootLayer.bounds.midX,
                                                 y: self.rootLayer.bounds.midY)
        self.rootLayer.addSublayer(self.detectionOverlay)
        self.detectionOverlay.isHidden = true
    }
    
    
    @IBAction func prevButton(_ sender: Any) {
        if stateController.step > 1 {
            stateController.step -= 1
        }
        print("\(stateController.step)")
        updateARView()
    }

    @IBAction func nextButton(_ sender: Any) {
        stateController.step += 1
        print("\(stateController.step)")
        updateARView()
    }
    
    @IBAction func menuButton(_ sender: Any) {
        // --- PopUP View: Gives user 2 options ----
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            let pop = Popup(frame: CGRect(), viewController: self)
                    self.view.addSubview(pop)
        }
    }
    
    func updateARView() -> Void {
        // main menu, view when popup is showed
        if stateController.step == 0 {
        }
        else if stateController.step == 1 {
            // --- show Buttons ---
            self.detectionOverlay.isHidden = true
            self.previousButton.isHidden = false
            self.nextButton.isHidden = false
            
            statusViewController.showMessage("POINT CAMERA TOWARDS MOTHEROARD")
        }
        else if stateController.step == 2 {
            //step 1, depress RAM levers
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadRAM1()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            notificationTrigger = anchor.notifications.stepRAM2
            statusViewController.showMessage("DEPRESS THE WHITE LEVERS")
        }
        else if stateController.step == 3 {
            //step 2, insert RAM sticks
            notificationTrigger.post()
            statusViewController.showMessage("PLACE RAM STICKS IN UNTIL CLICK")
        }
        //open cpu lever socket thing before this
        else if stateController.step == 4 {
            //step 3, insert CPU
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadCPU()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            //notificationTrigger = anchor.notifications.stepRAM2
            statusViewController.showMessage("PLACE THE CPU INTO THE SOCKET")
        }
}

    class StateController {
        var step: Int = 0
    }
    
}


extension ViewController {
    
    func drawVisionRequestResults(_ results: [Any]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil // remove all the old recognized objects
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            // Select only the label with the highest confidence.
            let topLabelObservation = objectObservation.labels[0]
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            
            let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
            
            let textLayer = self.createTextSubLayerInBounds(objectBounds,
                                                            identifier: topLabelObservation.identifier,
                                                            confidence: topLabelObservation.confidence)
            shapeLayer.addSublayer(textLayer)
            detectionOverlay.addSublayer(shapeLayer)
        }
        self.updateLayerGeometry()
        CATransaction.commit()
    }
    
    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\nConfidence:  %.2f", confidence))
        let largeFont = UIFont(name: "Helvetica", size: 18.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: -bounds.size.width/2 - 10, y: -bounds.size.height/2 + 30, width: bounds.size.height - 10, height: bounds.size.width - 10)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        textLayer.contentsScale = 2.0 // retina rendering
        // rotate the layer into screen orientation and scale and mirror
        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
        return textLayer
    }
    
    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 0.2, 0.4])
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }
    
    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // When rate-limiting predicitons, skip frames to predict every x
        if shouldSkipFrame > 0 {
            shouldSkipFrame = (shouldSkipFrame + 1) % predictEvery
        }

        predictionQueue.async {
            /// - Tag: MappingOrientation
            // The frame is always oriented based on the camera sensor,
            // so in most cases Vision needs to rotate it for the model to work as expected.
            let orientation = UIDevice.current.orientation

            // The image captured by the camera
            let image = frame.capturedImage

            let imageOrientation: CGImagePropertyOrientation
            switch orientation {
            case .portrait:
                imageOrientation = .right
            case .portraitUpsideDown:
                imageOrientation = .left
            case .landscapeLeft:
                imageOrientation = .up
            case .landscapeRight:
                imageOrientation = .down
            case .unknown:
                print("The device orientation is unknown, the predictions may be affected")
                fallthrough
            default:
                // By default keep the last orientation
                // This applies for faceUp and faceDown
                imageOrientation = self.lastOrientation
            }


            /// - Tag: PassingFramesToVision

            // Invoke a VNRequestHandler with that image
            let handler = VNImageRequestHandler(cvPixelBuffer: image, orientation: imageOrientation, options: [:])

            do {
                try handler.perform(self.requests)
            } catch {
                print("CoreML request failed with error: \(error.localizedDescription)")
            }

        }
    }
}
