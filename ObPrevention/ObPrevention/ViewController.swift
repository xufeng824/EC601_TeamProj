//
//  ViewController.swift
//  ObPrevention
//
//  Created by 沈栩烽 on 11/12/22.
//

import UIKit
import Metal
import ARKit
import CoreGraphics

class ViewController: UIViewController, ARSessionDelegate {
    
    // Voice module
    let language = "zh-CN"
    
    func Speak(_ stringToSpeak: String){
        let utterance = AVSpeechUtterance(string: stringToSpeak)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        // utterance.rate = AVSpeechUtteranceMaximumSpeechRate
        // utterance.rate = 0.7
        utterance.rate = AVSpeechUtteranceMaximumSpeechRate
        //utterance.postUtteranceDelay = 0.8
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
        // print(stringToSpeak)
    }
    
    @IBOutlet weak var imageView: UIImageView!
    
    var session: ARSession!
    var configuration = ARWorldTrackingConfiguration()
    
    var camWidth: Float?
    var camHeight: Float?
    var camOx: Float?
    var camOy: Float?
    var camFx: Float?
    var camFy: Float?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set this view controller as the session's delegate.
        session = ARSession()
        session.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Enable the smoothed scene depth frame-semantic.
        //configuration.frameSemantics = .smoothedSceneDepth
        configuration.frameSemantics = .sceneDepth
        
        
        // Run the view's session.
        session.run(configuration)
        
        // The screen shouldn't dim during AR experiences.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    // Show the result
    @IBOutlet weak var Rsout: UILabel!
    
    

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // guard let depthMap = frame.smoothedSceneDepth?.depthMap
        guard let depthMap = frame.sceneDepth?.depthMap
        else { return }
        
        // let camIntrinsicsMartix = frame.capturedDepthData?.cameraCalibrationData?.intrinsicMatrix
        let camIntrinsicsMartix = frame.camera.intrinsics
        //let camImageResolution = frame.capturedDepthData?.cameraCalibrationData?.intrinsicMatrixReferenceDimensions
        let camImageResolution = frame.camera.imageResolution
        
        self.camFx = camIntrinsicsMartix[0][0]
        self.camFy = camIntrinsicsMartix[1][1]
        self.camOx = camIntrinsicsMartix[0][2] // u0
        self.camOy = camIntrinsicsMartix[1][2] // v0
        self.camWidth = Float(camImageResolution.width)
        self.camHeight = Float(camImageResolution.height)
        
        /*
         if (CVPixelBufferIsPlanar(depthMap)) {
         print("Buffer is planar")
         }
         */
        
        let depthMapHeight = CVPixelBufferGetHeight(depthMap)
        let depthMapWidth = CVPixelBufferGetWidth(depthMap)
        
        //print("depthmap w/h: ", w, h)
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        //print("w,h, bytesPerRow:", h, w, bytesPerRow) // 192, 256
        
        /*
         let f = CVPixelBufferGetPixelFormatType(depthMap)
         switch f {
         case kCVPixelFormatType_DepthFloat32:
         print("format: kCVPixelFormatType_DepthFloat32")
         case kCVPixelFormatType_OneComponent8:
         print("format: kCVPixelFormatType_OneComponent8")
         default:
         print("format: unknown")
         }
         */
        
        CVPixelBufferLockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0))
        let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(depthMap), to: UnsafeMutablePointer<Float32>.self)
        // it should be kCVPixelFormatType_DepthFloat32
        // Arbitrary values of x and y to sample
        let depthMapX = depthMapWidth/2; // must be lower that cols
        let depthMapY = depthMapHeight/2; // must be lower than rows
        
        let baseAddressIndex = depthMapY  * depthMapWidth + depthMapX;
        // transder to float type
        let pixelValue = floatBuffer[baseAddressIndex];
        CVPixelBufferUnlockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0))
        
        // print("Pixel @ \(u),\(v): \(pixel)")
        
        // Da die DepthMap eine Größe von 256 * 192 (w * h) und die cam 1920 x 1440 entspricht die die Position des
        // Tiefenwerts an der Stelle (u,v) in der DepthMap der Postion u / w * camWidth, v / h * camHeight der cam
        
        // Scale from depthMap to cam
        let camX = Float(depthMapX) / Float(depthMapWidth) * camWidth!
        let camY = Float(depthMapY) / Float(depthMapHeight) * camHeight!
        
        // Calculate X/Y/Z
        let worldZ = pixelValue //  pixelValue/sqrt(camX*camX+camY*camY) // pythagoras!
        let worldX = (camX - camOx!) * worldZ / camFx!
        let worldY = (camY - camOy!) * worldZ / camFy!
        //let worldX = (20 * camWidth! - camOx!) * worldZ / camFx!
        //let worldY = (30 * camHeight! - camOy!) * worldZ / camFy!
        
        let interfaceOrientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? UIInterfaceOrientation.unknown
        /*
         if (interfaceOrientation.isPortrait) {
         print("Portrait")
         }
         if (interfaceOrientation.isLandscape) {
         print("Landscape")
         }
         */
        
        let viewPort = imageView.bounds
        let viewPortSize = imageView.bounds.size
        let depthMapSize = CGSize(width: depthMapWidth, height: depthMapHeight)
        
        // print("viewPortSize:",viewPortSize)
        
        depthMap.sinus(withMaxDepth: 6, andFrequence: 1)
        
        let depthBuffer = CIImage(cvPixelBuffer: depthMap)
        
        
        // 1) Convert to "normalized image coordinates"
        let normalizeTransform = CGAffineTransform(scaleX: 1.0/depthMapSize.width, y: 1.0/depthMapSize.height)
        
        // 2) Flip the Y axis (for some mysterious reason this is only necessary in portrait mode)
        let flipTransform = (interfaceOrientation.isPortrait) ? CGAffineTransform(scaleX: -1, y: -1).translatedBy(x: -1, y: -1) : .identity
        
        // 3) Apply the transformation provided by ARFrame
        // This transformation converts:
        // - From Normalized image coordinates (Normalized image coordinates range from (0,0) in the upper left corner of the image to (1,1) in the lower right corner)
        // - To view coordinates ("a coordinate space appropriate for rendering the camera image onscreen")
        // See also: https://developer.apple.com/documentation/arkit/arframe/2923543-displaytransform
        
        let displayTransform = frame.displayTransform(for: interfaceOrientation, viewportSize: viewPortSize)
        
        // 4) Convert to view size
        let toViewPortTransform = CGAffineTransform(scaleX: viewPortSize.width, y: viewPortSize.height)
        
        // Transform the image and crop it to the viewport
        let transformedImage = depthBuffer.transformed(by: normalizeTransform.concatenating(flipTransform).concatenating(displayTransform).concatenating(toViewPortTransform)).cropped(to: viewPort)
        
        
        // let displayImage = UIImage(ciImage: transformedImage)
        let displayImage = UIImage(ciImage: transformedImage)
        
        DispatchQueue.main.async {
            self.imageView.image = displayImage
        }
        
        // print("X = \(worldX) cm, Y = \(worldY) cm, Z = \(worldZ) cm")
        
        //Rsout.text = "X = \(worldX) cm, Y = \(worldY) cm, Z = \(worldZ) cm"
        
        // Rsout.text = "distance = \(baseAddressIndex)"
        Rsout.text = "distance = \(worldZ)"
        
        if(worldZ < 1){
            Rsout.text = "Watch out"
            Speak("嘟")
        }
        else{
            Rsout.text = "distance = \(worldZ)"
            
        }
    }

}
