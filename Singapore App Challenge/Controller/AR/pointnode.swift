//
//  pointnode.swift
//  Singapore App Challenge
//
//  Created by Octavianus Gandajaya on 10/7/17.
//  Copyright © 2017 Octavianus Gandajaya. All rights reserved.
//

import Foundation
import SceneKit

let POINT_SIZE = CGFloat(0.003)
let POINT_HEIGHT = CGFloat(0.00001)

class PointNode: SCNNode {
    
    static var boxGeo: SCNBox?
    
    override init() {
        super.init()
        
        if PointNode.boxGeo == nil {
            PointNode.boxGeo = SCNBox(width: POINT_SIZE, height: POINT_HEIGHT, length: POINT_SIZE, chamferRadius: 0.001)
            
            // Setup the material of the point
            let material = PointNode.boxGeo!.firstMaterial
            material?.lightingModel = SCNMaterial.LightingModel.blinn
            material?.diffuse.contents  = UIImage(named: "wood-diffuse.jpg")
            material?.normal.contents   = UIImage(named: "wood-normal.png")
            material?.specular.contents = UIImage(named: "wood-specular.jpg")
        }
        
        let object = SCNNode(geometry: PointNode.boxGeo!)
        object.transform = SCNMatrix4MakeTranslation(0.0, Float(POINT_HEIGHT) / 2.0, 0.0)
        
        self.addChildNode(object)
        
    }
    
    init(color: UIColor) {
        super.init()
        
        let boxGeo = SCNBox(width: POINT_SIZE, height: POINT_HEIGHT * 2.0, length: POINT_SIZE, chamferRadius: 0.001)
        boxGeo.firstMaterial?.diffuse.contents = UIColor.red
        
        let object = SCNNode(geometry: boxGeo)
        object.transform = SCNMatrix4MakeTranslation(0.0, Float(POINT_HEIGHT * 2.0) / 2.0, 0.0)
        
        self.addChildNode(object)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func getChildBoundingBox() -> (v1: SCNVector3, v2: SCNVector3) {
        let firstChild = self.childNodes[0]
        return (firstChild.boundingBox.max, firstChild.boundingBox.min)
    }
    
    func setNewHeight(newHeight: CGFloat) {
        PointNode.boxGeo?.height = newHeight
        let firstChild = self.childNodes[0]
        firstChild.transform = SCNMatrix4MakeTranslation(0.0, Float(newHeight / 2.0), 0.0)
    }
    
    func resetHeight() {
        PointNode.boxGeo?.height = POINT_HEIGHT
        let firstChild = self.childNodes[0]
        firstChild.transform = SCNMatrix4MakeTranslation(0.0, Float(POINT_HEIGHT / 2.0), 0.0)
    }
    
    
}

extension float3 {
    func length() -> Float {
        return sqrtf(x * x + y * y + z * z)
    }
    
    static func + (left: float3, right: float3) -> float3 {
        return float3(left.x + right.x, left.y + right.y, left.z + right.z)
    }
    
    static func - (left: float3, right: float3) -> float3 {
        return float3(left.x - right.x, left.y - right.y, left.z - right.z)
    }
    
}
