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
    var firstRun = true
    let predictionsToShow = 1
    let imagePredictor = ImagePredictor()
    
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var verifyButton: UIButton!
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
        
        self.verifyButton.isHidden = true
        
        arView.session.delegate = self
        rootLayer = arView.layer
        
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
        do {
            try  videoDevice!.lockForConfiguration()
            bufferSize.width = CGFloat(arView.frame.width)
            bufferSize.height = CGFloat(arView.frame.height)
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
                        self.drawVisionRequestResults(results)
                    }
                })
            })
            self.requests = [objectRecognition]
        } catch let error as NSError {
            print("Model loading went wrong: \(error)")
        }
        stateController = StateController()
        self.statusViewController.showMessage("IDENTIFY PC PARTS")
        self.menuButton.isHidden = false
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
//        self.detectionOverlay.isHidden = true
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
        self.detectionOverlay.isHidden = !(self.detectionOverlay.isHidden)
        
        if self.detectionOverlay.isHidden == true {
            let config = UIImage.SymbolConfiguration(hierarchicalColor: .secondaryLabel)
            let image = UIImage(systemName: "magnifyingglass.circle.fill", withConfiguration: config)
            self.menuButton.setImage(image, for: .normal)
        }
        else {
            let config = UIImage.SymbolConfiguration(hierarchicalColor: .systemBlue)
            let image = UIImage(systemName: "magnifyingglass.circle.fill", withConfiguration: config)
            self.menuButton.setImage(image, for: .normal)
        }

    }
    
    @IBAction func verifyStep(_ sender: Any) {
        // Show options for the source picker only if the camera is available.
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return
        }
        present(cameraPicker, animated: false)
    }
    
    
    func updateARView() -> Void {
        // main menu, view when popup is showed
        if stateController.step == 0 {
        }
        //STEP1: PLACE RAMS STICKS
        else if stateController.step == 1 {
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
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadRAM2SHORTSIDE()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Locate the short side of the RAM".uppercased())
        }
        else if stateController.step == 4 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadRAM2ALIGNMENT()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Align the ram as shown (short side down)".uppercased())
        }
        else if stateController.step == 5 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadRAM2INSERT()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Insert the RAMs into the RAM slots".uppercased())
        }
        //STEP 2: PLACE CPU
        else if stateController.step == 6 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadCPUOPENCOVER()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Open the CPU Cover".uppercased())
        }
        else if stateController.step == 7 {
            //step 3, insert CPU
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadCPU()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Place the CPU into the Socket".uppercased())
        }
        else if stateController.step == 8 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadCPUCLOSECOVER()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Close the CPU Cover".uppercased())
        }
        //STEP 3: PLACE CPU FAN
        else if stateController.step == 9 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadCPUFAN1ORIENTATION1()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("orient CPU FAN as shown".uppercased())
        }
        else if stateController.step == 10 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadCPUFAN()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Place the CPU FAN over the CPU".uppercased())
        }
        else if stateController.step == 11 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadCPUFANSCREW1()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Place screw 1 into hole of CPU FAN".uppercased())
        }
        else if stateController.step == 12 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadCPUFANSCREW2()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Place screw 2 into hole of CPU FAN".uppercased())
        }
        else if stateController.step == 13 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadCPUFANSCREW3()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Place screw 3 into hole of CPU FAN".uppercased())
        }
        else if stateController.step == 14 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadCPUFANSCREW4()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Place screw 4 into hole of CPU FAN".uppercased())
        }
        //STEP 4: Place Motherboard into Case
        else if stateController.step == 15 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadPCCASEMOTHERBOARD()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Place motherboard into case".uppercased())
        }
        //STEP 4.1: Screws into the 8 holes to secure motherboard
        else if stateController.step == 16 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadMBSCREW1()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Place screw 1 into hole of motherboard".uppercased())
        }
        else if stateController.step == 17 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadMBSCREW2()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Place screw 2 into hole of motherboard".uppercased())
        }
        else if stateController.step == 18 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadMBSCREW3()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Place screw 3 into hole of motherboard".uppercased())
        }
        else if stateController.step == 19 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadMBSCREW4()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Place screw 4 into hole of motherboard".uppercased())
        }
        else if stateController.step == 20 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadMBSCREW5()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Place screw 5 into hole of motherboard".uppercased())
        }
        else if stateController.step == 21 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadMBSCREW6()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Place screw 6 into hole of motherboard".uppercased())
        }
        else if stateController.step == 22 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadMBSCREW7()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Place screw 7 into hole of motherboard".uppercased())
        }
        else if stateController.step == 23 {
            arView.scene.anchors.removeAll()
            let anchor = try! RAM.loadMBSCREW8()
            anchor.generateCollisionShapes(recursive: true)
            arView.scene.anchors.append(anchor)
            statusViewController.showMessage("Place screw 8 into hole of motherboard".uppercased())
        }
        //STEP 5: Place Hard Drive into case until click
        else if stateController.step == 24 {
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

extension ViewController {
    // MARK: Main storyboard updates
    /// Updates the storyboard's image view.
    /// - Parameter image: An image.
//    func updateImage(_ image: UIImage) {
//        DispatchQueue.main.async {
//            self.imageView.image = image
//        }
//    }

    /// Updates the storyboard's prediction label.
    /// - Parameter message: A prediction or message string.
    /// - Tag: updatePredictionLabel
    func updatePredictionLabel(_ message: String) {
        DispatchQueue.main.async {
            self.statusViewController.showMessage(message)
        }

        if firstRun {
            DispatchQueue.main.async {
                self.firstRun = false
                //self.predictionLabel.superview?.isHidden = false
                //self.startupPrompts.isHidden = true
            }
        }
    }
    /// Notifies the view controller when a user selects a photo in the camera picker or photo library picker.
    /// - Parameter photo: A photo from the camera or photo library.
    func userSelectedPhoto(_ photo: UIImage) {
        //updateImage(photo)
        //statusViewController.showMessage("Making predictions for the photo...")

        DispatchQueue.global(qos: .userInitiated).async {
            self.classifyImage(photo)
        }
    }
}

extension ViewController {
    // MARK: Image prediction methods
    /// Sends a photo to the Image Predictor to get a prediction of its content.
    /// - Parameter image: A photo.
    private func classifyImage(_ image: UIImage) {
        do {
            try self.imagePredictor.makePredictions(for: image,
                                                    completionHandler: imagePredictionHandler)
        } catch {
            statusViewController.showMessage("Vision was unable to make a prediction")
        }
    }

    /// The method the Image Predictor calls when its image classifier model generates a prediction.
    /// - Parameter predictions: An array of predictions.
    /// - Tag: imagePredictionHandler
    private func imagePredictionHandler(_ predictions: [ImagePredictor.Prediction]?) {
        guard let predictions = predictions else {
            statusViewController.showMessage("No predictions. (Check console log.)")
            return
        }

        let formattedPredictions = formatPredictions(predictions)

        let predictionString = formattedPredictions.joined(separator: "\n")
        updatePredictionLabel(predictionString)
    }

    /// Converts a prediction's observations into human-readable strings.
    /// - Parameter observations: The classification observations from a Vision request.
    /// - Tag: formatPredictions
    private func formatPredictions(_ predictions: [ImagePredictor.Prediction]) -> [String] {
        // Vision sorts the classifications in descending confidence order.
        let topPredictions: [String] = predictions.prefix(predictionsToShow).map { prediction in
            var name = prediction.classification

            // For classifications with more than one name, keep the one before the first comma.
            if let firstComma = name.firstIndex(of: ",") {
                name = String(name.prefix(upTo: firstComma))
            }

            return "\(name) - \(prediction.confidencePercentage)%"
        }

        return topPredictions
    }
}

