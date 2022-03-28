//
//  InstructionMilestoneView.swift
//  PC Building
//
//  Created by Irene Lee on 2022-03-26.
//

import UIKit
import SceneKit
import SpriteKit

class InstructionMilestoneView: UIViewController {
    
 
    @IBOutlet var milestoneView: UIVisualEffectView!
    @IBOutlet weak var sceneView: SCNView!
    
    @IBOutlet weak var stepLabel: UILabel!
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var instructionDetail: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1: Load .obj file
        let scene = SCNScene(named: "Random_access_memory_RAM_DDR3scn.scn")
        
        //print(scene?.rootNode.childNodes)
        let obj_node = scene?.rootNode.childNode(withName: "scene", recursively: false)
        obj_node?.runAction(SCNAction.repeatForever(SCNAction.rotate(by: 2*M_PI, around: SCNVector3(x: 0, y: 1, z: 0), duration: 7)))
        
        
        // 6: Creating and adding ambien light to scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor.white
        scene?.rootNode.addChildNode(ambientLightNode)
        
        
        // Allow user to manipulate camera
        sceneView.allowsCameraControl = false
        
        // Allow user translate image
        sceneView.cameraControlConfiguration.allowsTranslation = false
        
        sceneView.layer.cornerRadius = sceneView.frame.size.width/2
        sceneView.clipsToBounds = true

        // Set scene settings
        sceneView.scene = scene
        
    }
    
    func hideMilestoneView(){
        self.milestoneView?.isHidden = true
    }
    
    func showMilestoneView(){
        self.milestoneView?.isHidden = false
    }
    
    func changeLabel(stepLabel:String, instructionLabel:String){
        self.stepLabel.text = stepLabel
        self.instructionsLabel.text = instructionLabel
    }
    
    func changeScene(sceneName:String){
        // 1: Load .obj file
        let scene = SCNScene(named: sceneName)
        
        //print(scene?.rootNode.childNodes)
        let obj_node = scene?.rootNode.childNode(withName: "scene", recursively: false)
        obj_node?.runAction(SCNAction.repeatForever(SCNAction.rotate(by: 2*M_PI, around: SCNVector3(x: 0, y: 1, z: 0), duration: 7)))
        
        
        // 6: Creating and adding ambien light to scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor.white
        scene?.rootNode.addChildNode(ambientLightNode)

        // Set scene settings
        sceneView.scene = scene
    }
    
    @IBAction func startAssembly(_ sender: Any) {
        hideMilestoneView()
    }
    
}
