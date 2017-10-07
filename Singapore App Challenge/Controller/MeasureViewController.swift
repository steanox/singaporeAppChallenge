//
//  MeasureViewController.swift
//  Singapore App Challenge
//
//  Created by Octavianus Gandajaya on 10/7/17.
//  Copyright © 2017 Octavianus Gandajaya. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class MeasureViewController: UIViewController , ARSCNViewDelegate{

    @IBOutlet weak var lengthIndicatorLabel: UILabel!
    @IBOutlet weak var lengthLabel: UILabel!
    @IBOutlet weak var waitView: UIStackView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var aimLabel: UILabel!
    @IBOutlet weak var directionImage: UIImageView!
    @IBOutlet weak var info: UILabel!
    
    let session = ARSession()
    let vectorZero = SCNVector3()
    let sessionConfig: ARConfiguration = ARWorldTrackingConfiguration()
    var measuring = false
    var startValue = SCNVector3()
    var endValue = SCNVector3()
    
    var flag = 0
    var cm: Float = 0.0
    var length = 0
    var width = 0
    var height = 0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.layer.opacity = 0.3
        aimLabel.isHidden = true
        spinner.startAnimating()
        waitView.isHidden = false
 
        setupScene()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        session.pause()
    }
    
    func setupScene() {
        sceneView.delegate = self
        sceneView.session = session
        
        info.isHidden = true
        directionImage.isHidden = true
        lengthLabel.text = "0.00 Cm"
        

        session.run(sessionConfig, options: [.resetTracking, .removeExistingAnchors])
        
        resetValues()
    }
    
    func resetValues() {
        measuring = false
        startValue = SCNVector3()
        endValue =  SCNVector3()
        
        updateResultLabel(0.0)
    }
    
    func updateResultLabel(_ value: Float) {
        cm = value * 100.0
    
        lengthLabel.text = String(format: "%.2f cm", cm)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.detectObjects()
        }
    }
    
    func detectObjects() {
        
       
        
        if let worldPos = sceneView.realWorldVector(screenPos: view.center) {
            info.isHidden = false
            directionImage.isHidden = false
            waitView.isHidden = true
            sceneView.layer.opacity = 1
            aimLabel.isHidden = false
            
            if measuring {
                if startValue == vectorZero {
                    startValue = worldPos
                }
                
                endValue = worldPos
                updateResultLabel(startValue.distance(from: endValue))
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if flag == 0{
            lengthIndicatorLabel.text = "Width"
            
        }
        if flag == 1{

        }
        if flag == 2{

            
        }
        
        lengthIndicatorLabel.isHidden = false
        lengthLabel.isHidden = false
        
        resetValues()
        measuring = true
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        
        measuring = false
        checkFlag()
        flag += 1
    }
    
    func checkFlag() {
        lengthLabel.text = "0.00 Cm"
       
        if flag == 0 {
            lengthIndicatorLabel.text = "Depth"
            directionImage.image = #imageLiteral(resourceName: "insideOutside")
            length = Int(cm)
        } else if flag == 1 {
            lengthIndicatorLabel.text = "Height"
            directionImage.image = #imageLiteral(resourceName: "upDown")
            width = Int(cm)
        } else if flag == 2 {
            height = Int(cm)
            print("success")
        }
        print(cm)
    }


}

extension SCNVector3: Equatable {
    static func positionFromTransform(_ transform: matrix_float4x4) -> SCNVector3 {
        return SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
    
    func distance(from vector: SCNVector3) -> Float {
        let distanceX = self.x - vector.x
        let distanceY = self.y - vector.y
        let distanceZ = self.z - vector.z
        
        return sqrtf( (distanceX * distanceX) + (distanceY * distanceY) + (distanceZ * distanceZ))
    }
    
    public static func ==(lhs: SCNVector3, rhs: SCNVector3) -> Bool {
        return (lhs.x == rhs.x) && (lhs.y == rhs.y) && (lhs.z == rhs.z)
    }
}

extension ARSCNView {
    func realWorldVector(screenPos: CGPoint) -> SCNVector3? {
        let planeTestResults = self.hitTest(screenPos, types: [.featurePoint])
        if let result = planeTestResults.first {
            return SCNVector3.positionFromTransform(result.worldTransform)
        }
        
        return nil
    }
}

