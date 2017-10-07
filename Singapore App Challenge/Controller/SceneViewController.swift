//
//  SceneViewController.swift
//  Singapore App Challenge
//
//  Created by Octavianus Gandajaya on 10/7/17.
//  Copyright © 2017 Octavianus Gandajaya. All rights reserved.
//

import UIKit
import ARKit
import Foundation
import SceneKit
import Vision

enum Setting: String {
    case scaleWithPinchGesture
    case dragOnInfinitePlanes
    
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Setting.dragOnInfinitePlanes.rawValue: true
            ])
    }
}


class SceneViewController: UIViewController {

    
    @IBOutlet weak var scene: ARSCNView!
    private let handler = VNSequenceRequestHandler()
    var in3DMode = false
    
    var inDrawMode = false
    var screenCenter: CGPoint?
    var virtualPenTip: PointNode?
    
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var messagePanel: UIView!
    var trackImageInitialOrigin: CGPoint?
    var lastFingerWorldPos: float3?
    var trackImageBoundingBox: CGRect?
    
     let trackImageSize = CGFloat(20)
    
    let standardConfiguration: ARWorldTrackingConfiguration = {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        return configuration
    }()
    
    @IBOutlet weak var drawButton: UIButton!
    fileprivate var lastObservation: VNDetectedObjectObservation?
    @IBAction func drawAction() {
        drawButton.isSelected = !drawButton.isSelected
        inDrawMode = drawButton.isSelected
        in3DMode = false
    }
    
    @objc private func tapAction(recognizer: UITapGestureRecognizer) {
        
        lastObservation = nil
        let tapLocation = recognizer.location(in: view)
        
        // Set up the rect in the image in view coordinate space that we will track
        let trackImageBoundingBoxOrigin = CGPoint(x: tapLocation.x - trackImageSize / 2, y: tapLocation.y - trackImageSize / 2)
        trackImageBoundingBox = CGRect(origin: trackImageBoundingBoxOrigin, size: CGSize(width: trackImageSize, height: trackImageSize))
        
        let t = CGAffineTransform(scaleX: 1.0 / self.view.frame.size.width, y: 1.0 / self.view.frame.size.height)
        let normalizedTrackImageBoundingBox = trackImageBoundingBox!.applying(t)
        
        // Transfrom the rect from view space to image space
        guard let fromViewToCameraImageTransform = self.scene.session.currentFrame?.displayTransform(for: UIInterfaceOrientation.portrait, viewportSize: self.scene.frame.size).inverted() else {
            return
        }
        var trackImageBoundingBoxInImage =  normalizedTrackImageBoundingBox.applying(fromViewToCameraImageTransform)
        trackImageBoundingBoxInImage.origin.y = 1 - trackImageBoundingBoxInImage.origin.y   // Image space uses bottom left as origin while view space uses top left
        
        lastObservation = VNDetectedObjectObservation(boundingBox: trackImageBoundingBoxInImage)
        
    }
    
    
    @IBOutlet weak var threeDMagicButton: UIButton!
    @IBAction func threeDMagicAction(_ button: UIButton) {
        threeDMagicButton.isSelected = !threeDMagicButton.isSelected
        in3DMode = threeDMagicButton.isSelected
        inDrawMode = false
        
        trackImageInitialOrigin = nil
    }
    
    var focusSquare: FocusSquare?
    var textManager: TextManager!
    
    var virtualObjectManager: VirtualObjectManager!
    
    var spinner: UIActivityIndicatorView?
    
    
    let serialQueue = DispatchQueue(label: "com.apple.arkitexample.serialSceneKitQueue")
    
    
    var session: ARSession = ARSession()
    

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scene.session = self.session
        
        scene.delegate = self
        
        Setting.registerDefaults()
        setupUIControls()
        setupScene()
        
        setupFocusSquare()
    
    }
    
    func setupScene() {
        // Synchronize updates via the `serialQueue`.
        virtualObjectManager = VirtualObjectManager(updateQueue: serialQueue)
        virtualObjectManager.delegate = self
        
        // set up scene view
        scene.setup()
        
        scene.session = session
        // sceneView.showsStatistics = true
        
        scene.scene.enableEnvironmentMapWithIntensity(25, queue: serialQueue)
        
        setupFocusSquare()
        
        DispatchQueue.main.async {
            self.screenCenter = self.scene.bounds.mid
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    

    
    
    func setupUIControls() {
        textManager = TextManager(viewController: self)
        
        // Set appearance of message output panel
        messagePanel.layer.cornerRadius = 3.0
        messagePanel.clipsToBounds = true
        messagePanel.isHidden = true
        messageLabel.text = ""
    }

    
    func setupFocusSquare() {
        serialQueue.async {
            self.focusSquare?.isHidden = true
            self.focusSquare?.removeFromParentNode()
            self.focusSquare = FocusSquare()
            self.scene.scene.rootNode.addChildNode(self.focusSquare!)
        }
        
        textManager.scheduleMessage("TRY MOVING LEFT OR RIGHT", inSeconds: 5.0, messageType: .focusSquare)
    }
    
    func updateFocusSquare() {
        guard let screenCenter = screenCenter else { return }
        
        DispatchQueue.main.async {
            var objectVisible = false
            for object in self.virtualObjectManager.virtualObjects {
                if self.scene.isNode(object, insideFrustumOf: self.scene.pointOfView!) {
                    objectVisible = true
                    break
                }
            }
            
            if objectVisible {
                self.focusSquare?.hide()
            } else {
                self.focusSquare?.unhide()
            }
            
            let (worldPos, planeAnchor, _) = self.virtualObjectManager.worldPositionFromScreenPosition(screenCenter,
                                                                                                       in: self.scene,
                                                                                                       objectPos: self.focusSquare?.simdPosition)
            if let worldPos = worldPos {
                self.serialQueue.async {
                    self.focusSquare?.update(for: worldPos, planeAnchor: planeAnchor, camera: self.session.currentFrame?.camera)
                }
                self.textManager.cancelScheduledMessage(forType: .focusSquare)
            }
        }
    }
    
    var planes = [ARPlaneAnchor: Plane]()
    
    func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
        
        let plane = Plane(anchor)
        planes[anchor] = plane
        node.addChildNode(plane)
        
        textManager.cancelScheduledMessage(forType: .planeEstimation)
        textManager.showMessage("SURFACE DETECTED")
        if virtualObjectManager.virtualObjects.isEmpty {
            textManager.scheduleMessage("TAP + TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .contentPlacement)
        }
    }
    
    func updatePlane(anchor: ARPlaneAnchor) {
        if let plane = planes[anchor] {
            plane.update(anchor)
        }
    }
    
    func removePlane(anchor: ARPlaneAnchor) {
        if let plane = planes.removeValue(forKey: anchor) {
            plane.removeFromParentNode()
        }
    }
    
    func resetTracking() {
        session.run(standardConfiguration, options: [.resetTracking, .removeExistingAnchors])
        
        textManager.scheduleMessage("FIND A SURFACE TO PLACE AN OBJECT",
                                    inSeconds: 7.5,
                                    messageType: .planeEstimation)
        
        trackImageInitialOrigin = nil
        inDrawMode = false
        in3DMode = false
        lastFingerWorldPos = nil
        drawButton.isSelected = false
        threeDMagicButton.isSelected = false
        self.virtualPenTip?.isHidden = true
        
    }
    
    //error handling
    
    func displayErrorMessage(title: String, message: String, allowRestart: Bool = false) {
        // Blur the background.
        textManager.blurBackground()
        
        if allowRestart {
            // Present an alert informing about the error that has occurred.
            let restartAction = UIAlertAction(title: "Reset", style: .default) { _ in
                self.textManager.unblurBackground()
               
            }
            textManager.showAlert(title: title, message: message, actions: [restartAction])
        } else {
            textManager.showAlert(title: title, message: message, actions: [])
        }
    }
}

extension SceneViewController: ARSCNViewDelegate{
    
    fileprivate func handle(_ request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let newObservation = request.results?.first as? VNDetectedObjectObservation else {
                return
            }
            self.lastObservation = newObservation
            
            // check the confidence level before updating the UI
            guard newObservation.confidence >= 0.3 else {
                // hide the pen when we lose accuracy so the user knows something is wrong
                self.virtualPenTip?.isHidden = true
                self.lastObservation = nil
                return
            }
            
            var trackImageBoundingBoxInImage = newObservation.boundingBox
            
            // Transfrom the rect from image space to view space
            trackImageBoundingBoxInImage.origin.y = 1 - trackImageBoundingBoxInImage.origin.y
            guard let fromCameraImageToViewTransform = self.scene.session.currentFrame?.displayTransform(for: UIInterfaceOrientation.portrait, viewportSize: self.scene.frame.size) else {
                return
            }
            let normalizedTrackImageBoundingBox = trackImageBoundingBoxInImage.applying(fromCameraImageToViewTransform)
            let t = CGAffineTransform(scaleX: self.view.frame.size.width, y: self.view.frame.size.height)
            let unnormalizedTrackImageBoundingBox = normalizedTrackImageBoundingBox.applying(t)
            self.trackImageBoundingBox = unnormalizedTrackImageBoundingBox
            
            // Get the projection if the location of the tracked image from image space to the nearest detected plane
            if let trackImageOrigin = self.trackImageBoundingBox?.origin {
                (self.lastFingerWorldPos, _, _) = self.virtualObjectManager.worldPositionFromScreenPosition(CGPoint(x: trackImageOrigin.x - 20.0, y: trackImageOrigin.y + 40.0), in: self.scene, objectPos: nil, infinitePlane: false)
            }
            
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        updateFocusSquare()
        
        // If light estimation is enabled, update the intensity of the model's lights and the environment map
        guard let pixelBuffer = self.scene.session.currentFrame?.capturedImage,
            let observation = self.lastObservation else {
                return
        }
        let request = VNTrackObjectRequest(detectedObjectObservation: observation) { [unowned self] request, error in
            self.handle(request, error: error)
        }
        request.trackingLevel = .accurate
        do {
            try self.handler.perform([request], on: pixelBuffer)
        }
        catch {
            print(error)
        }
        
        if let lightEstimate = self.session.currentFrame?.lightEstimate {
            self.scene.scene.enableEnvironmentMapWithIntensity(lightEstimate.ambientIntensity / 40, queue: serialQueue)
        } else {
            self.scene.scene.enableEnvironmentMapWithIntensity(40, queue: serialQueue)
        }
        
        if (self.virtualPenTip == nil) {
            self.virtualPenTip = PointNode(color: UIColor.red)
            self.scene.scene.rootNode.addChildNode(self.virtualPenTip!)
        }
        
        // Draw
        
        if let lastFingerWorldPos = self.lastFingerWorldPos {
            
            // Update virtual pen position
            self.virtualPenTip?.isHidden = false
            self.virtualPenTip?.simdPosition = lastFingerWorldPos
            
            // Draw new point
            if (self.inDrawMode && !self.virtualObjectManager.pointNodeExistAt(pos: lastFingerWorldPos)){
                let newPoint = PointNode()
                self.scene.scene.rootNode.addChildNode(newPoint)
                self.virtualObjectManager.loadVirtualObject(newPoint, to: lastFingerWorldPos)
            }
            
            // Convert drawing to 3D
            if (self.in3DMode ) {
                if self.trackImageInitialOrigin != nil {
                    DispatchQueue.main.async {
                        let newH = 0.4 *  (self.trackImageInitialOrigin!.y - self.trackImageBoundingBox!.origin.y) / self.scene.frame.height
                        self.virtualObjectManager.setNewHeight(newHeight: newH)
                    }
                }
                else {
                    self.trackImageInitialOrigin = self.trackImageBoundingBox?.origin
                }
            }
            
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        serialQueue.async {
            self.addPlane(node: node, anchor: planeAnchor)
            self.virtualObjectManager.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor, planeAnchorNode: node)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        serialQueue.async {
            self.updatePlane(anchor: planeAnchor)
            self.virtualObjectManager.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor, planeAnchorNode: node)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        serialQueue.async {
            self.removePlane(anchor: planeAnchor)
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        textManager.showTrackingQualityInfo(for: camera.trackingState, autoHide: true)
        
        switch camera.trackingState {
        case .notAvailable:
            fallthrough
        case .limited:
            textManager.escalateFeedback(for: camera.trackingState, inSeconds: 3.0)
        case .normal:
            textManager.cancelScheduledMessage(forType: .trackingStateEscalation)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard let arError = error as? ARError else { return }
        
        let nsError = error as NSError
        var sessionErrorMsg = "\(nsError.localizedDescription) \(nsError.localizedFailureReason ?? "")"
        if let recoveryOptions = nsError.localizedRecoveryOptions {
            for option in recoveryOptions {
                sessionErrorMsg.append("\(option).")
            }
        }
        
        let isRecoverable = (arError.code == .worldTrackingFailed)
        if isRecoverable {
            sessionErrorMsg += "\nYou can try resetting the session or quit the application."
        } else {
            sessionErrorMsg += "\nThis is an unrecoverable error that requires to quit the application."
        }
        
        displayErrorMessage(title: "We're sorry!", message: sessionErrorMsg, allowRestart: isRecoverable)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        textManager.blurBackground()
        textManager.showAlert(title: "Session Interrupted", message: "The session will be reset after the interruption has ended.")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        textManager.unblurBackground()
        session.run(standardConfiguration, options: [.resetTracking, .removeExistingAnchors])
        //restartExperience(self)
        textManager.showMessage("RESETTING SESSION")
    }
}


extension SceneViewController:  VirtualObjectManagerDelegate {

    
    
    

    
    
    // MARK: - VirtualObjectManager delegate callbacks
    
    func virtualObjectManager(_ manager: VirtualObjectManager, willLoad object: PointNode) {
        DispatchQueue.main.async {
            // Show progress indicator
            self.spinner = UIActivityIndicatorView()
            self.spinner!.center = self.view.center
            self.spinner!.bounds.size = CGSize(width: 100, height: 100)
            
            self.scene.addSubview(self.spinner!)
            self.spinner!.startAnimating()
            
            
        }
    }
    
    func virtualObjectManager(_ manager: VirtualObjectManager, didLoad object: VirtualObject) {
        DispatchQueue.main.async {
            
            // Remove progress indicator
            self.spinner?.removeFromSuperview()
        }
    }
    
    func virtualObjectManager(_ manager: VirtualObjectManager, couldNotPlace object: VirtualObject) {
        
        textManager.showMessage("CANNOT PLACE OBJECT\nTry moving left or right.")
    }
    
    func worldPositionFromScreenPosition(_ position: CGPoint,
                                         in sceneView: ARSCNView,
                                         objectPos: float3?,
                                         infinitePlane: Bool = false) -> (position: float3?, planeAnchor: ARPlaneAnchor?, hitAPlane: Bool) {
        
        //let dragOnInfinitePlanesEnabled = UserDefaults.standard.bool(for: .dragOnInfinitePlanes)
        
        // -------------------------------------------------------------------------------
        // 1. Always do a hit test against exisiting plane anchors first.
        //    (If any such anchors exist & only within their extents.)
        
        let planeHitTestResults = sceneView.hitTest(position, types: .existingPlaneUsingExtent)
        if let result = planeHitTestResults.first {
            
            let planeHitTestPosition = result.worldTransform.translation
            let planeAnchor = result.anchor
            
            // Return immediately - this is the best possible outcome.
            return (planeHitTestPosition, planeAnchor as? ARPlaneAnchor, true)
        }
   
        
        return (nil, nil, false)
    }
    // MARK: - VirtualObjectSelectionViewControllerDelegate
    
    
    
}


