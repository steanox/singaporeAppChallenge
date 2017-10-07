//
//  File.swift
//  Singapore App Challenge
//
//  Created by Octavianus Gandajaya on 10/7/17.
//  Copyright © 2017 Octavianus Gandajaya. All rights reserved.
//

import Foundation
import ARKit
import SceneKit

class Plane: SCNNode {
    
    // MARK: - Properties
    
    var anchor: ARPlaneAnchor
    var focusSquare: FocusSquare?
    
    // MARK: - Initialization
    
    init(_ anchor: ARPlaneAnchor) {
        self.anchor = anchor
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - ARKit
    
    func update(_ anchor: ARPlaneAnchor) {
        self.anchor = anchor
    }
    
}

extension ARSCNView {
    
    func setup() {
        antialiasingMode = .multisampling4X
        automaticallyUpdatesLighting = false
        
        preferredFramesPerSecond = 60
        contentScaleFactor = 1.3
        
        if let camera = pointOfView?.camera {
            camera.wantsHDR = true
            camera.wantsExposureAdaptation = true
            camera.exposureOffset = -1
            camera.minimumExposure = -1
            camera.maximumExposure = 3
        }
    }
}

// MARK: - Scene extensions

extension SCNScene {
    func enableEnvironmentMapWithIntensity(_ intensity: CGFloat, queue: DispatchQueue) {
        queue.async {
            if self.lightingEnvironment.contents == nil {
                if let environmentMap = UIImage(named: "Models.scnassets/sharedImages/environment_blur.exr") {
                    self.lightingEnvironment.contents = environmentMap
                }
            }
            self.lightingEnvironment.intensity = intensity
        }
    }
}


class Gesture {
    
    // MARK: - Types
    
    enum TouchEventType {
        case touchBegan
        case touchMoved
        case touchEnded
        case touchCancelled
    }
    
    // MARK: - Properties
    
    let sceneView: ARSCNView
    let objectManager: VirtualObjectManager
    
    var refreshTimer: Timer?
    
    var lastUsedObject: VirtualObject?
    
    var currentTouches = Set<UITouch>()
    
    // MARK: - Initialization
    
    init(_ touches: Set<UITouch>, _ sceneView: ARSCNView, _ lastUsedObject: VirtualObject?, _ objectManager: VirtualObjectManager) {
        currentTouches = touches
        self.sceneView = sceneView
        self.lastUsedObject = lastUsedObject
        self.objectManager = objectManager
        
        // Refresh the current gesture at 60 Hz - This ensures smooth updates even when no
        // new touch events are incoming (but the camera might have moved).
        self.refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.016_667, repeats: true, block: { _ in
            self.updateGesture()
        })
    }
    
    // MARK: Static Functions
    
    static func startGestureFromTouches(_ touches: Set<UITouch>, _ sceneView: ARSCNView, _ lastUsedObject: VirtualObject?, _ objectManager: VirtualObjectManager) -> Gesture? {
        if touches.count == 1 {
            return SingleFingerGesture(touches, sceneView, lastUsedObject, objectManager)
        } else if touches.count == 2 {
            return TwoFingerGesture(touches, sceneView, lastUsedObject, objectManager)
        } else {
            return nil
        }
    }
    
    /// Hit tests against the `sceneView` to find an object at the provided point.
    func virtualObject(at point: CGPoint) -> VirtualObject? {
        let hitTestOptions: [SCNHitTestOption: Any] = [.boundingBoxOnly: true]
        let hitTestResults: [SCNHitTestResult] = sceneView.hitTest(point, options: hitTestOptions)
        
        return hitTestResults.lazy.flatMap { result in
            VirtualObject.isNodePartOfVirtualObject(result.node)
            }.first
    }
    
    // MARK: - Gesture Handling
    
    func updateGesture() {
        // Customize in `Gesture` subclasses.
    }
    
    func updateGestureFromTouches(_ touches: Set<UITouch>, _ type: TouchEventType) -> Gesture? {
        if touches.isEmpty {
            // No touches -> Do nothing.
            return self
        }
        
        // Update the set of current touches.
        if type == .touchBegan || type == .touchMoved {
            currentTouches = touches.union(currentTouches)
        } else if type == .touchEnded || type == .touchCancelled {
            currentTouches.subtract(touches)
        }
        
        if let singleFingerGesture = self as? SingleFingerGesture {
            
            if currentTouches.count == 1 {
                // Update this gesture.
                singleFingerGesture.updateGesture()
                return singleFingerGesture
            } else {
                // Finish this single finger gesture and switch to two finger or no gesture.
                singleFingerGesture.finishGesture()
                singleFingerGesture.refreshTimer?.invalidate()
                singleFingerGesture.refreshTimer = nil
                return Gesture.startGestureFromTouches(currentTouches, sceneView, lastUsedObject, objectManager)
            }
        } else if let twoFingerGesture = self as? TwoFingerGesture {
            
            if currentTouches.count == 2 {
                // Update this gesture.
                twoFingerGesture.updateGesture()
                return twoFingerGesture
            } else {
                // Finish this two finger gesture and switch to no gesture -> The user
                // will have to release all other fingers and touch the screen again
                // to start a new gesture.
                twoFingerGesture.finishGesture()
                twoFingerGesture.refreshTimer?.invalidate()
                twoFingerGesture.refreshTimer = nil
                return nil
            }
        } else {
            return self
        }
    }
    
}

class SingleFingerGesture: Gesture {
    
    // MARK: - Properties
    
    var initialTouchLocation = CGPoint()
    var latestTouchLocation = CGPoint()
    
    var firstTouchedObject: VirtualObject?
    
    let translationThreshold: CGFloat = 30
    var translationThresholdPassed = false
    var hasMovedObject = false
    
    var dragOffset = CGPoint()
    
    // MARK: - Initialization
    
    override init(_ touches: Set<UITouch>, _ sceneView: ARSCNView, _ lastUsedObject: VirtualObject?, _ objectManager: VirtualObjectManager) {
        super.init(touches, sceneView, lastUsedObject, objectManager)
        
        let touch = currentTouches.first!
        initialTouchLocation = touch.location(in: sceneView)
        latestTouchLocation = initialTouchLocation
        
        firstTouchedObject = virtualObject(at: initialTouchLocation)
    }
    
    // MARK: - Gesture Handling
    
    override func updateGesture() {
        super.updateGesture()
        
        guard let virtualObject = firstTouchedObject else {
            return
        }
        
        latestTouchLocation = currentTouches.first!.location(in: sceneView)
        
        if !translationThresholdPassed {
            let initialLocationToCurrentLocation = latestTouchLocation - initialTouchLocation
            let distanceFromStartLocation = initialLocationToCurrentLocation.length()
            if distanceFromStartLocation >= translationThreshold {
                translationThresholdPassed = true
                
                let currentObjectLocation = CGPoint(sceneView.projectPoint(virtualObject.position))
                dragOffset = latestTouchLocation - currentObjectLocation
            }
        }
        
        // A single finger drag will occur if the drag started on the object and the threshold has been passed.
        if translationThresholdPassed {
            
            let offsetPos = latestTouchLocation - dragOffset
            objectManager.translate(virtualObject, in: sceneView, basedOn: offsetPos, instantly: false, infinitePlane: true)
            hasMovedObject = true
            lastUsedObject = virtualObject
        }
    }
    
    func finishGesture() {
        // Single finger touch allows teleporting the object or interacting with it.
        
        // Do not do anything if this gesture is being finished because
        // another finger has started touching the screen.
        if currentTouches.count > 1 {
            return
        }
        
        // Do not do anything either if the touch has dragged the object around.
        if hasMovedObject {
            return
        }
        
        if lastUsedObject != nil {
            // If this gesture hasn't moved the object then perform a hit test against
            // the geometry to check if the user has tapped the object itself.
            // - Note: If the object covers a significant
            // percentage of the screen then we should interpret the tap as repositioning
            // the object.
            let isObjectHit = virtualObject(at: latestTouchLocation) != nil
            
            if !isObjectHit {
                // Teleport the object to whereever the user touched the screen - as long as the
                // drag threshold has not been reached.
                if !translationThresholdPassed {
                    objectManager.translate(lastUsedObject!, in: sceneView, basedOn: latestTouchLocation, instantly: true, infinitePlane: false)
                }
            }
        }
    }
    
}

class TwoFingerGesture: Gesture {
    
    // MARK: - Properties
    
    var firstTouch = UITouch()
    var secondTouch = UITouch()
    
    let translationThreshold: CGFloat = 40
    let translationThresholdHarder: CGFloat = 70
    var translationThresholdPassed = false
    var allowTranslation = false
    var dragOffset = CGPoint()
    var initialMidPoint = CGPoint(x: 0, y: 0)
    
    let rotationThreshold: Float = .pi / 15 // (12°)
    let rotationThresholdHarder: Float = .pi / 10 // (18°)
    var rotationThresholdPassed = false
    var allowRotation = false
    var initialFingerAngle: Float = 0
    var initialObjectAngle: Float = 0
    var firstTouchedObject: VirtualObject?
    
    let scaleThreshold: CGFloat = 50
    let scaleThresholdHarder: CGFloat = 90
    var scaleThresholdPassed = false
    
    var initialDistanceBetweenFingers: CGFloat = 0
    var baseDistanceBetweenFingers: CGFloat = 0
    var objectBaseScale: Float = 1.0
    
    // MARK: - Initialization
    
    override init(_ touches: Set<UITouch>, _ sceneView: ARSCNView, _ lastUsedObject: VirtualObject?, _ objectManager: VirtualObjectManager) {
        super.init(touches, sceneView, lastUsedObject, objectManager)
        let touches = Array(touches)
        firstTouch = touches[0]
        secondTouch = touches[1]
        
        let firstTouchPoint = firstTouch.location(in: sceneView)
        let secondTouchPoint = secondTouch.location(in: sceneView)
        initialMidPoint = firstTouchPoint.midpoint(secondTouchPoint)
        
        // Compute the two other corners of the rectangle defined by the two fingers
        let thirdCorner = CGPoint(x: firstTouchPoint.x, y: secondTouchPoint.y)
        let fourthCorner = CGPoint(x: secondTouchPoint.x, y: firstTouchPoint.y)
        
        // Compute all midpoints between the corners and center of the rectangle.
        let midPoints = [
            thirdCorner.midpoint(firstTouchPoint),
            thirdCorner.midpoint(secondTouchPoint),
            fourthCorner.midpoint(firstTouchPoint),
            fourthCorner.midpoint(secondTouchPoint),
            initialMidPoint.midpoint(firstTouchPoint),
            initialMidPoint.midpoint(secondTouchPoint),
            initialMidPoint.midpoint(thirdCorner),
            initialMidPoint.midpoint(fourthCorner)
        ]
        
        // Check if any of the two fingers or their midpoint is touching the object.
        // Based on that, translation, rotation and scale will be enabled or disabled.
        let allPoints = [firstTouchPoint, secondTouchPoint, thirdCorner, fourthCorner, initialMidPoint] + midPoints
        firstTouchedObject = allPoints.lazy.flatMap { point in
            return self.virtualObject(at: point)
            }.first
        if let virtualObject = firstTouchedObject {
            objectBaseScale = virtualObject.scale.x
            
            allowTranslation = true
            allowRotation = true
            
            initialDistanceBetweenFingers = (firstTouchPoint - secondTouchPoint).length()
            
            initialFingerAngle = atan2(Float(initialMidPoint.x), Float(initialMidPoint.y))
            initialObjectAngle = virtualObject.eulerAngles.y
        } else {
            allowTranslation = false
            allowRotation = false
        }
    }
    
    // MARK: - Gesture Handling
    
    override func updateGesture() {
        super.updateGesture()
        
        guard let virtualObject = firstTouchedObject else {
            return
        }
        
        // Two finger touch enables combined translation, rotation and scale.
        
        // First: Update the touches.
        let touches = Array(currentTouches)
        let newTouch1 = touches[0]
        let newTouch2 = touches[1]
        
        if newTouch1 == firstTouch {
            firstTouch = newTouch1
            secondTouch = newTouch2
        } else {
            firstTouch = newTouch2
            secondTouch = newTouch1
        }
        
        let loc1 = firstTouch.location(in: sceneView)
        let loc2 = secondTouch.location(in: sceneView)
        
        if allowTranslation {
            // 1. Translation using the midpoint between the two fingers.
            updateTranslation(of: virtualObject, midpoint: loc1.midpoint(loc2))
        }
        
        let spanBetweenTouches = loc1 - loc2
        if allowRotation {
            // 2. Rotation based on the relative rotation of the fingers on a unit circle.
            updateRotation(of: virtualObject, span: spanBetweenTouches)
        }
    }
    
    func updateTranslation(of virtualObject: VirtualObject, midpoint: CGPoint) {
        if !translationThresholdPassed {
            
            let initialLocationToCurrentLocation = midpoint - initialMidPoint
            let distanceFromStartLocation = initialLocationToCurrentLocation.length()
            
            // Check if the translate gesture has crossed the threshold.
            // If the user is already rotating and or scaling we use a bigger threshold.
            
            var threshold = translationThreshold
            if rotationThresholdPassed || scaleThresholdPassed {
                threshold = translationThresholdHarder
            }
            
            if distanceFromStartLocation >= threshold {
                translationThresholdPassed = true
                
                let currentObjectLocation = CGPoint(sceneView.projectPoint(virtualObject.position))
                dragOffset = midpoint - currentObjectLocation
            }
        }
        
        if translationThresholdPassed {
            let offsetPos = midpoint - dragOffset
            objectManager.translate(virtualObject, in: sceneView, basedOn: offsetPos, instantly: false, infinitePlane: true)
            lastUsedObject = virtualObject
        }
    }
    
    func updateRotation(of virtualObject: VirtualObject, span: CGPoint) {
        let midpointToFirstTouch = span / 2
        let currentAngle = atan2(Float(midpointToFirstTouch.x), Float(midpointToFirstTouch.y))
        
        let currentAngleToInitialFingerAngle = initialFingerAngle - currentAngle
        
        if !rotationThresholdPassed {
            var threshold = rotationThreshold
            
            if translationThresholdPassed || scaleThresholdPassed {
                threshold = rotationThresholdHarder
            }
            
            if abs(currentAngleToInitialFingerAngle) > threshold {
                
                rotationThresholdPassed = true
                
                // Change the initial object angle to prevent a sudden jump after crossing the threshold.
                if currentAngleToInitialFingerAngle > 0 {
                    initialObjectAngle += threshold
                } else {
                    initialObjectAngle -= threshold
                }
            }
        }
        
        if rotationThresholdPassed {
            // Note:
            // For looking down on the object (99% of all use cases), we need to subtract the angle.
            // To make rotation also work correctly when looking from below the object one would have to
            // flip the sign of the angle depending on whether the object is above or below the camera...
            virtualObject.eulerAngles.y = initialObjectAngle - currentAngleToInitialFingerAngle
            lastUsedObject = virtualObject
        }
    }
    
    func finishGesture() {
        // Nothing to do here for two finger gestures.
    }
}

extension ARSCNView {
    
    // MARK: - Types
    
    struct HitTestRay {
        let origin: float3
        let direction: float3
    }
    
    struct FeatureHitTestResult {
        let position: float3
        let distanceToRayOrigin: Float
        let featureHit: float3
        let featureDistanceToHitResult: Float
    }
    
    func unprojectPoint(_ point: float3) -> float3 {
        return float3(self.unprojectPoint(SCNVector3(point)))
    }
    
    // MARK: - Hit Tests
    
    func hitTestRayFromScreenPos(_ point: CGPoint) -> HitTestRay? {
        
        guard let frame = self.session.currentFrame else {
            return nil
        }
        
        let cameraPos = frame.camera.transform.translation
        
        // Note: z: 1.0 will unproject() the screen position to the far clipping plane.
        let positionVec = float3(x: Float(point.x), y: Float(point.y), z: 1.0)
        let screenPosOnFarClippingPlane = self.unprojectPoint(positionVec)
        
        let rayDirection = simd_normalize(screenPosOnFarClippingPlane - cameraPos)
        return HitTestRay(origin: cameraPos, direction: rayDirection)
    }
    
    func hitTestWithInfiniteHorizontalPlane(_ point: CGPoint, _ pointOnPlane: float3) -> float3? {
        
        guard let ray = hitTestRayFromScreenPos(point) else {
            return nil
        }
        
        // Do not intersect with planes above the camera or if the ray is almost parallel to the plane.
        if ray.direction.y > -0.03 {
            return nil
        }
        
        // Return the intersection of a ray from the camera through the screen position with a horizontal plane
        // at height (Y axis).
        return rayIntersectionWithHorizontalPlane(rayOrigin: ray.origin, direction: ray.direction, planeY: pointOnPlane.y)
    }
    
    func hitTestWithFeatures(_ point: CGPoint, coneOpeningAngleInDegrees: Float,
                             minDistance: Float = 0,
                             maxDistance: Float = Float.greatestFiniteMagnitude,
                             maxResults: Int = 1) -> [FeatureHitTestResult] {
        
        var results = [FeatureHitTestResult]()
        
        guard let features = self.session.currentFrame?.rawFeaturePoints else {
            return results
        }
        
        guard let ray = hitTestRayFromScreenPos(point) else {
            return results
        }
        
        let maxAngleInDeg = min(coneOpeningAngleInDegrees, 360) / 2
        let maxAngle = (maxAngleInDeg / 180) * .pi
        
        let points = features.__points
        
        for i in 0...features.__count {
            
            let feature = points.advanced(by: Int(i))
            let featurePos = feature.pointee
            
            let originToFeature = featurePos - ray.origin
            
            let crossProduct = simd_cross(originToFeature, ray.direction)
            let featureDistanceFromResult = simd_length(crossProduct)
            
            let hitTestResult = ray.origin + (ray.direction * simd_dot(ray.direction, originToFeature))
            let hitTestResultDistance = simd_length(hitTestResult - ray.origin)
            
            if hitTestResultDistance < minDistance || hitTestResultDistance > maxDistance {
                // Skip this feature - it is too close or too far away.
                continue
            }
            
            let originToFeatureNormalized = simd_normalize(originToFeature)
            let angleBetweenRayAndFeature = acos(simd_dot(ray.direction, originToFeatureNormalized))
            
            if angleBetweenRayAndFeature > maxAngle {
                // Skip this feature - is is outside of the hit test cone.
                continue
            }
            
            // All tests passed: Add the hit against this feature to the results.
            results.append(FeatureHitTestResult(position: hitTestResult,
                                                distanceToRayOrigin: hitTestResultDistance,
                                                featureHit: featurePos,
                                                featureDistanceToHitResult: featureDistanceFromResult))
        }
        
        // Sort the results by feature distance to the ray.
        results = results.sorted(by: { (first, second) -> Bool in
            return first.distanceToRayOrigin < second.distanceToRayOrigin
        })
        
        // Cap the list to maxResults.
        var cappedResults = [FeatureHitTestResult]()
        var i = 0
        while i < maxResults && i < results.count {
            cappedResults.append(results[i])
            i += 1
        }
        
        return cappedResults
    }
    
    func hitTestWithFeatures(_ point: CGPoint) -> [FeatureHitTestResult] {
        
        var results = [FeatureHitTestResult]()
        
        guard let ray = hitTestRayFromScreenPos(point) else {
            return results
        }
        
        if let result = self.hitTestFromOrigin(origin: ray.origin, direction: ray.direction) {
            results.append(result)
        }
        
        return results
    }
    
    func hitTestFromOrigin(origin: float3, direction: float3) -> FeatureHitTestResult? {
        
        guard let features = self.session.currentFrame?.rawFeaturePoints else {
            return nil
        }
        
        let points = features.__points
        
        // Determine the point from the whole point cloud which is closest to the hit test ray.
        var closestFeaturePoint = origin
        var minDistance = Float.greatestFiniteMagnitude
        
        for i in 0...features.__count {
            let feature = points.advanced(by: Int(i))
            let featurePos = feature.pointee
            
            let originVector = origin - featurePos
            let crossProduct = simd_cross(originVector, direction)
            let featureDistanceFromResult = simd_length(crossProduct)
            
            if featureDistanceFromResult < minDistance {
                closestFeaturePoint = featurePos
                minDistance = featureDistanceFromResult
            }
        }
        
        // Compute the point along the ray that is closest to the selected feature.
        let originToFeature = closestFeaturePoint - origin
        let hitTestResult = origin + (direction * simd_dot(direction, originToFeature))
        let hitTestResultDistance = simd_length(hitTestResult - origin)
        
        return FeatureHitTestResult(position: hitTestResult,
                                    distanceToRayOrigin: hitTestResultDistance,
                                    featureHit: closestFeaturePoint,
                                    featureDistanceToHitResult: minDistance)
    }
    
}



