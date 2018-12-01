import UIKit
import AVFoundation
import Vision
import Photos
import Surge

let imageSize = 368

var last_score = 50

class CameraViewController: UIViewController {
    @IBOutlet weak var cameraView: UIImageView!
    @IBOutlet weak var previewView: UIImageView!
    @IBOutlet weak var messageLabel: UILabelStroked!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabelStroked!
    
    @IBOutlet weak var captureButton: UIButton!
    
    let timeIntervalBeforeCaptureStart = 1
    let timeIntervalToCapture = 1
//    let timeIntervalBeforeCaptureStart = 1
//    let timeIntervalToCapture = 1

    var isRecording = false
    var text_timeIntervalBeforeCaptureStart = "%d seconds to prepare"
    var text_timeIntervalToCapture = "%d seconds captured"
    var messageLabel_text: String?
    
    // one random frame from the recorded video used in Trial view
    var randomImage: UIImage?
    var linesInFrames: [[Line]] = []

    let com = {
        Common(imageSize,imageSize)
    }()
    
    let modelCoreML = MobileOpenPose()
    let targetImageSize = CGSize(width: imageSize, height: imageSize) // must match model data input
    
    var captureSession = AVCaptureSession()
    var captureDevice: AVCaptureDevice?
    let videoDevice = AVCaptureDevice.default(for: AVMediaType.video)
    var cameraLayer: AVCaptureVideoPreviewLayer!
    
    let fileOutput = AVCaptureMovieFileOutput()
    var selectedFileURL: URL?
    var editingImage: UIImage?
    var completedDetection: Bool = false
    
    var deviceType: UIUserInterfaceIdiom?
    var isIPhoneX: Bool = false
    
    var canUseCamera: Bool?
    var canUsePhotoLibrary: Bool?
    
    fileprivate func openTrialView() {
        self.performSegue(withIdentifier: "Trial details", sender: nil)
        
        self.captureButton.isHidden = false
        self.messageLabel.isHidden = false
        
        self.messageLabel.text = self.messageLabel_text
    }
    
    @IBAction func tappedCaptureButton(sender: UIButton) {
        
        if !isRecording {
            
            let timerStartedAt = Date()
            
            DispatchQueue.main.async {
                self.messageLabel.isHidden = false
                self.captureButton.isHidden = true
            }
            
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { (timer) in
                DispatchQueue.main.async {
                    let diff = self.timeIntervalBeforeCaptureStart + Int(timerStartedAt.timeIntervalSinceNow)
                    self.messageLabel.text = String(format: self.text_timeIntervalBeforeCaptureStart, diff)
                    
                    if diff <= 0 {
                        timer.invalidate()
                        
                        // start shooting...
                        
                        AudioServicesPlaySystemSound(SystemSoundID(1322));
                        
                        // start recording
                        self.shootVideo()
                        
                        let timerStartedAt = Date()
                        
                        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { (timer) in
                            DispatchQueue.main.async {
                                let diff = -Int(timerStartedAt.timeIntervalSinceNow)
                                self.messageLabel.text = String(format: self.text_timeIntervalToCapture, diff)
                                
                                if diff >= self.timeIntervalToCapture {
                                    
                                    timer.invalidate()
                                    
                                    AudioServicesPlaySystemSound(SystemSoundID(1313));
                                    
                                    // stop recording
                                    self.shootVideo()
                                }
                            }
                            
                        }
                        
                        timer.fire()
                        
                    }
                }
                
            }
            
            timer.fire()
        }
    }
    
    //    @IBOutlet weak var selectButton: UIButton!
    //    @IBAction func tappedSelectButton(sender: UIButton) {
    //        selectVideo()
    //    }
    
    func classificationRequest(completion: @escaping (_ request: VNRequest, _ error: Error?) -> Void) -> [VNRequest] {
        do {
            // Load the Custom Vision model.
            // To add a new model, drag it to the Xcode project browser making sure that the "Target Membership" is checked.
            // Then update the following line with the name of your new model.
            let model = try VNCoreMLModel(for: modelCoreML.model)
            let classificationRequest = VNCoreMLRequest(model: model, completionHandler: completion)
            
            return [ classificationRequest ]
        } catch {
            fatalError("Can't load Vision ML model: \(error)")
        }
    }
    
    func drawLine(_ mm: Array<Double>, lines: inout [Line]) {
        let connections = com.estimatePose(mm)
        let CocoPairsRender = com.cocoPairs[0..<com.cocoPairs.count-2]
        
        UIGraphicsBeginImageContext(targetImageSize)
        var context:CGContext = UIGraphicsGetCurrentContext()!
        
        for human in connections.values {
            for (partIdx, part) in human.enumerated() {
                if (partIdx >= com.cocoColors.count){ continue }
                if !CocoPairsRender.contains(part.partIdx){ continue }
                
                let center1 = CGPoint(x: (CGFloat(part.c1.0) + 0.5) * 8,
                                      y: (CGFloat(part.c1.1) + 0.5) * 8)
                let center2 = CGPoint(x: (CGFloat(part.c2.0) + 0.5) * 8,
                                      y: (CGFloat(part.c2.1) + 0.5) * 8)
                
                guard let color = com.cocoColors[partIdx] else {continue}
                
                addLine(context: &context, fromPoint: center1, toPoint: center2, color: color)
                
                let line = Line( center1, center2)
                lines.append(line)
            }
        }
        
        var boneImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        var mainImage: UIImage = editingImage!
        
        // Resize width to a multiple of 16.
        mainImage = com.resizeImage(image: mainImage, size: mainImage.size, useToMakeVideo: true)
        
        // Crop bone image.
        // Since the image for detection was resized while keeping the aspect ratio at self.uIImageToPixelBuffer,
        // it's necessary to remove padding.
        let boneImageCropped: UIImage = com.cropImage(image: boneImage, aspectX: mainImage.size.width, aspectY: mainImage.size.height)
        
        // Fit to the size of main image.
        boneImage = com.resizeImage(image: boneImageCropped, size: mainImage.size)
        
        // Superimpose the image and bones.
        editingImage = com.superimposeImages(mainImage: mainImage, subImage: boneImage)
        
        completedDetection = true
    }
    
    func addLine(context: inout CGContext, fromPoint start: CGPoint, toPoint end:CGPoint, color: UIColor) {
        context.setLineWidth(3.0)
        context.setStrokeColor(color.cgColor)
        
        context.move(to: start)
        context.addLine(to: end)
        
        context.closePath()
        context.strokePath()
    }
    
    func shootVideo() {
        if !self.isRecording {
            // Start recording.
//            messageLabel.isHidden = true
            
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            let documentsDirectory = paths[0] as String
            let fileURL : NSURL = NSURL(fileURLWithPath: "\(documentsDirectory)/temp.mp4")
            fileOutput.startRecording(to: fileURL as URL, recordingDelegate: self)
            
            // Change the shape of capture button to square.
//            captureButton.layer.cornerRadius = 0
            isRecording = true
        } else {
            // Stop Recording.
            fileOutput.stopRecording()
            
            // Change the shape of capture button to circle.
//            captureButton.layer.cornerRadius = captureButton.bounds.width / 2
            isRecording = false
        }
    }
    
//    func updateSelectButton() {
//        let fetchOptions = PHFetchOptions()
//        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
//
//        let fetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions)
//        let last = fetchResult.lastObject
//
//        if let lastAsset = last {
//            // There are videos in photo library.
//            let targetSize: CGSize = CGSize(width: 50, height: 50)
//            let options: PHImageRequestOptions = PHImageRequestOptions()
//            options.version = .current
//
//            // Get the last video from photo library.
//            PHImageManager.default().requestImage(
//                for: lastAsset,
//                targetSize: targetSize,
//                contentMode: .aspectFit,
//                options: options,
//                resultHandler: { image, _ in
//                    if self.canUsePhotoLibrary! {
//                        DispatchQueue.main.async {
//                            self.selectButton.setImage(image, for: .normal)
//                            self.selectButton.isHidden = false
//                        }
//                    }
//                }
//            )
//        }
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        messageLabel_text = messageLabel.text
        
        deviceType = UIDevice.current.userInterfaceIdiom
        guard deviceType == .phone || deviceType == .pad else {
            fatalError("ERROR: Invalid device.")
        }
        
        let deviceName = com.getDeviceName()
        if deviceType == .phone && deviceName.range(of: "iPhone10") != nil {
            isIPhoneX = true
        }
        
        progressView.transform = CGAffineTransform(scaleX: 1.0, y: 3.0)
        
        cameraLayer = AVCaptureVideoPreviewLayer(session: self.captureSession) as AVCaptureVideoPreviewLayer
        cameraLayer.frame = self.view.bounds
        cameraLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        cameraView.layer.addSublayer(cameraLayer)
        
//        messageLabel.strokedText = "Sit-to-stand-test"
        
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.layer.borderWidth = 3
        
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
            if response {
                self.canUseCamera = true
                DispatchQueue.main.async {
                    self.captureButton.isHidden = false
                }
                self.setupCamera()
            } else {
                self.canUseCamera = false
            }
        }
        
        PHPhotoLibrary.requestAuthorization() { (status) -> Void in
            if status == .authorized {
                self.canUsePhotoLibrary = true
//                self.updateSelectButton()
            } else {
                self.canUsePhotoLibrary = false
                DispatchQueue.main.async {
                    self.captureButton.isHidden = true
                }
            }
        }
    }
    
//    override func viewDidAppear(_ animated: Bool) {
//        guard let url: URL = selectedFileURL else {
//            return
//        }
//
//        // Selected a video from photo library.
//        if ["MOV", "MP4", "M4V"].index(of: url.pathExtension.uppercased()) != nil {
//            detectBone(url)
//        } else {
//            showAlert(title: "", message: "You can select only mov, mp4 or m4v video.", btnText: "OK")
//        }
//
//        selectedFileURL = nil
//    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cameraLayer.frame = self.view.bounds
        
        if isIPhoneX {
            // Place view at (0, 0).
            cameraView.frame = CGRect(x: 0, y: 0, width: cameraView.frame.width, height: cameraView.frame.height)
        }
    }
    
    func setupCamera() {
        let deviceDiscovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)
        
        if let device = deviceDiscovery.devices.last {
            captureDevice = device
            beginSession()
        }
    }
    
    func beginSession() {
        let videoInput = try? AVCaptureDeviceInput(device: videoDevice!) as AVCaptureDeviceInput
        
        captureSession.addInput(videoInput!)
        captureSession.addOutput(fileOutput)

        if deviceType == .phone {
            // iPhone
            captureSession.sessionPreset = .hd1920x1080
        } else {
            // iPad
            captureSession.sessionPreset = .vga640x480
        }
        
        captureSession.startRunning()
    }
    
    func detectBone(_ inputURL: URL) {
        let outputURL: URL = NSURL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("\(NSUUID().uuidString).mp4")!
        
        guard let videoWriter = try? AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mov) else {
            print("ERROR: Failed to construct AVAssetWriter.")
            return
        }
        
        let avAsset = AVURLAsset(url: inputURL, options: nil)
        let composition = AVVideoComposition(asset: avAsset, applyingCIFiltersWithHandler: { request in })
        let track = avAsset.tracks(withMediaType: AVMediaType.video)
        
        guard let media = track[0] as AVAssetTrack? else {
            print("ERROR: There is no video track.")
            return
        }
        
        DispatchQueue.main.async {
//            self.messageLabel.isHidden = true
            self.captureButton.isHidden = true
//            self.selectButton.isHidden = true
            self.progressLabel.strokedText = "Detecting bones...(0%)"
            self.progressLabel.isHidden = false
            self.progressView.setProgress(0.0, animated: false)
            self.progressView.isHidden = false
        }
        
        let naturalSize: CGSize = media.naturalSize
        let preferedTransform: CGAffineTransform = media.preferredTransform
        let size = naturalSize.applying(preferedTransform)
        let width = fabs(size.width)
        let height = fabs(size.height)
        
        let outputSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ] as [String: Any]
        
        let writerInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings as [String : AnyObject])
        videoWriter.add(writerInput)
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )
        
        writerInput.expectsMediaDataInRealTime = true
        
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: kCMTimeZero)
        
        let generator = AVAssetImageGenerator(asset: avAsset)
        
        // Settings to get captures of all frames.
        // Without these settings, you can only get captures of integral seconds.
        generator.requestedTimeToleranceAfter = kCMTimeZero
        generator.requestedTimeToleranceBefore = kCMTimeZero
        
        var buffer: CVPixelBuffer? = nil
        var frameCount = 0
        let durationForEachImage = 1
        
        let length: Double = Double(CMTimeGetSeconds(avAsset.duration))
        let fps: Int = Int(1 / CMTimeGetSeconds(composition.frameDuration))
        
        DispatchQueue.global().async {
            DispatchQueue.main.async {
                self.cameraView.isHidden = true
            }
            
            var timeToGetRandomImage: Double? = Double.random(in: 0...(length/2))
            print("timeToGetRandomImage \(String(describing: timeToGetRandomImage)) length \(length)")

            self.linesInFrames = []

            for i in stride(from: 0, to: length, by: 1.0 / Double(fps)) {
                autoreleasepool {
                    
                    var lines: [Line] = []

                    // Capture an image from the video file.
                    let capturedImage : CGImage! = try? generator.copyCGImage(at: CMTime(seconds: i, preferredTimescale : 600), actualTime: nil)
                    
                    var orientation: UIImageOrientation
                    
                    // Rotate the captured image.
                    if preferedTransform.tx == naturalSize.width && preferedTransform.ty == naturalSize.height {
                        orientation = UIImageOrientation.down
                    } else if preferedTransform.tx == 0 && preferedTransform.ty == 0 {
                        orientation = UIImageOrientation.up
                    } else if preferedTransform.tx == 0 && preferedTransform.ty == naturalSize.width {
                        orientation = UIImageOrientation.left
                    } else {
                        orientation = UIImageOrientation.right
                    }
                    
                    let tmpImageToEdit = UIImage(cgImage: capturedImage, scale: 1.0, orientation: orientation)
                    
                    if let timeToGetRandomImageEffective = timeToGetRandomImage,
                        i >= timeToGetRandomImageEffective {
                        timeToGetRandomImage = nil
                        
                        self.randomImage = tmpImageToEdit
                    }

                    // Resize width to a multiple of 16.
                    self.editingImage = self.com.resizeImage(image: tmpImageToEdit, size: tmpImageToEdit.size, useToMakeVideo: true)
                    
                    let tmpImageToDetect: UIImage = UIImage(cgImage: capturedImage)
                    let bufferToDetect = self.uiImageToPixelBuffer(tmpImageToDetect, targetSize: self.targetImageSize, orientation: orientation)!
                    
                    do {
                        // Detect bones.
                        let classifierRequestHandler = VNImageRequestHandler(cvPixelBuffer: bufferToDetect, options: [:])
                        let classificationRequest = self.classificationRequest(completion: { (request: VNRequest, error: Error?) in
                            
                            guard let observations = request.results as? [VNCoreMLFeatureValueObservation] else { fatalError() }
                            let mlarray = observations[0].featureValue.multiArrayValue!
                            let length = mlarray.count
                            let doublePtr =  mlarray.dataPointer.bindMemory(to: Double.self, capacity: length)
                            let doubleBuffer = UnsafeBufferPointer(start: doublePtr, count: length)
                            let mm = Array(doubleBuffer)
                            
                            self.drawLine(mm, lines: &lines)
                        })
                        try classifierRequestHandler.perform(classificationRequest)
                    } catch {
                        print("Error: Failed to detect bones.")
                        print(error)
                    }
                    
                    // Repeat until the Detection is completed.
                    while true {
                        if self.completedDetection {
                            buffer = self.com.getPixelBufferFromCGImage(cgImage: self.editingImage!.cgImage!)
                            self.completedDetection = false
                            break
                        }
                    }
                    
                    let frameTime: CMTime = CMTimeMake(Int64(__int32_t(frameCount) * __int32_t(durationForEachImage)), __int32_t(fps))
                    
                    // Repeat until the adaptor is ready.
                    while true {
                        if (adaptor.assetWriterInput.isReadyForMoreMediaData) {
                            adaptor.append(buffer!, withPresentationTime: frameTime)
                            break
                        }
                    }
                    
                    frameCount += 1
                    
                    self.linesInFrames.append(lines)
                }
                
                let progressRate = floor(i / length * 100)
                
                DispatchQueue.main.async {
                    self.previewView.image = self.editingImage!
                    self.progressLabel.strokedText = "Detecting bones...(" + String(Int(progressRate)) + "%)"
                    self.progressView.setProgress(Float(progressRate / 100), animated: true)
                }
                
            }
            
            writerInput.markAsFinished()
            
            DispatchQueue.main.async {
                self.previewView.image = nil
                self.progressLabel.strokedText = "Detecting bones...(100%)"
                self.progressView.setProgress(1.0, animated: true)
                self.cameraView.isHidden = false
            }
            
            videoWriter.endSession(atSourceTime: CMTimeMake(Int64((__int32_t(frameCount)) *  __int32_t(durationForEachImage)), __int32_t(fps)))
            videoWriter.finishWriting(completionHandler: {
//                self.moveVideoToPhotoLibrary(outputURL)
//                self.showAlert(
//                    title: "", message: "Exported a video with detected bones to photo library.", btnText: "OK",
//                    completion: {
//                        () -> Void in
////                        self.updateSelectButton()
//                    }
//                )
            })
            
            DispatchQueue.main.async {
//                self.messageLabel.isHidden = false
                
                if self.canUsePhotoLibrary! {
                    if self.canUseCamera! {
                        self.captureButton.isHidden = false
                    }
//                    self.selectButton.isHidden = false
                }
                
                self.progressLabel.isHidden = true
                self.progressView.isHidden = true
                
                let result = self.calculateResult(linesInFrames: self.linesInFrames)
                session.activities.append(Activity(date: Date(), linesInFrames: self.linesInFrames, sampleImage: self.randomImage, score: result.0, status: result.1))
                
                self.openTrialView()
            }
            
        }
    }

    func calculateResult(linesInFrames: [[Line]]) -> (Int, String) {
        
        
        /*
         Common.swift
         ___________________
         enum CocoPart: Int {
         case Nose = 0
         case Neck = 1
         case RShoulder = 2
         case RElbow = 3
         case RWrist = 4
         case LShoulder = 5
         case LElbow = 6
         case LWrist = 7
         case RHip = 8
         case RKnee = 9
         case RAnkle = 10
         case LHip = 11
         case LKnee = 12
         case LAnkle = 13
         case REye = 14
         case LEye = 15
         case REar = 16
         case LEar = 17
         case Background = 18
         }
 
        */
        
        //to calculate the angle that the leg is bending we can compute between:
            //RHip - RKnee - RAnkle
            //LHip - LKnee - LAnkle
        
        var angleSignal: [CGFloat] = [];
        
        for frame in linesInFrames {
            
            var rightleg_angle: CGFloat = 0;
            var leftleg_angle: CGFloat = 0;
            
        
            if(frame.count >= 9) { //we must ensure that openpose actually found the segments in this frame, otherwise the
                                    //app will crash
                let RHip_to_RKnee: Line = frame[7];
                let RKnee_to_RAnkle: Line = frame[8];
                
                let RHip_to_RKnee_slope = computeSlopeOfSegment(segment: RHip_to_RKnee);
                let RKnee_to_RAnkle_slope = computeSlopeOfSegment(segment: RKnee_to_RAnkle);
                rightleg_angle = computeAngleBetweenTwoSlopes(slope1: RHip_to_RKnee_slope, slope2: RKnee_to_RAnkle_slope);
            }
            
            if (frame.count >= 11) { //for similar reasons as above, check length
                let LHip_to_LKnee: Line = frame[10];
                let LKnee_to_LAnkle: Line = frame[11];
                
                let LHip_to_LKnee_slope = computeSlopeOfSegment(segment: LHip_to_LKnee);
                let LKnee_to_LAnkle_slope = computeSlopeOfSegment(segment: LKnee_to_LAnkle);
                leftleg_angle = computeAngleBetweenTwoSlopes(slope1: LHip_to_LKnee_slope, slope2: LKnee_to_LAnkle_slope);
            }
            
            angleSignal.append(rightleg_angle + leftleg_angle);
        }
        
        
        
        last_score += 10
        return (last_score, "Well done!")
    }
    
    func computeAngleBetweenTwoSlopes(slope1: CGFloat, slope2: CGFloat) -> CGFloat{
        var temp_calc = (slope2 - slope1)/(1 + slope1*slope2)
        
        var angle_rad = CGFloat(Surge.atan(Double(temp_calc)))
        
        var angle = angle_rad * (180/CGFloat.pi)
        
        return angle;
    }
    
    func computeSlopeOfSegment(segment: Line) -> CGFloat {
        
        let x1 = segment.start.x;
        let y1 = segment.start.y;
        
        let x2 = segment.end.x;
        let y2 = segment.end.y;
        
        let slope: CGFloat = (y2 - y1)/(x2-x1);
        
        return slope;
    }
    
    
    
    func showAlert(title: String, message: String, btnText: String, completion: @escaping () -> Void = {}) {
        NSLog("showAlert \(title) \(message)")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: btnText, style: .default, handler: nil))
        present(alert, animated: true, completion: completion)
    }
    
//    func moveVideoToPhotoLibrary(_ url: URL) {
//        PHPhotoLibrary.shared().performChanges({
//            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url as URL)
//        }){ completed, error in
//            if error != nil {
//                print("ERROR: Failed to move a video file to Photo Library.")
//            }
//        }
//    }
    
    let ciContext = CIContext()
    var resultBuffer: CVPixelBuffer?
    
    func uiImageToPixelBuffer(_ uiImage: UIImage, targetSize: CGSize, orientation: UIImageOrientation) -> CVPixelBuffer? {
        var angle: CGFloat
            
        if orientation == UIImageOrientation.down {
            angle = CGFloat.pi
        } else if orientation == UIImageOrientation.up {
            angle = 0
        } else if orientation == UIImageOrientation.left {
            angle = CGFloat.pi / 2.0
        } else {
            angle = -CGFloat.pi / 2.0
        }
        
        let rotateTransform: CGAffineTransform = CGAffineTransform(translationX: targetSize.width / 2.0, y: targetSize.height / 2.0).rotated(by: angle).translatedBy(x: -targetSize.height / 2.0, y: -targetSize.width / 2.0)
        
        let uiImageResized = com.resizeImage(image: uiImage, size: targetSize, keepAspectRatio: true)
        let ciImage = CIImage(image: uiImageResized)!
        let rotated = ciImage.transformed(by: rotateTransform)
        
        // Only need to create this buffer one time and then we can reuse it for every frame
        if resultBuffer == nil {
            let result = CVPixelBufferCreate(kCFAllocatorDefault, Int(targetSize.width), Int(targetSize.height), kCVPixelFormatType_32BGRA, nil, &resultBuffer)
            
            guard result == kCVReturnSuccess else {
                fatalError("Can't allocate pixel buffer.")
            }
        }
        
        // Render the Core Image pipeline to the buffer
        ciContext.render(rotated, to: resultBuffer!)
        
        //  For debugging
        //  let image = imageBufferToUIImage(resultBuffer!)
        //  print(image.size) // set breakpoint to see image being provided to CoreML
        
        return resultBuffer
    }
    
    // Only used for debugging.
    // Turns an image buffer into a UIImage that is easier to display in the UI or debugger.
    func imageBufferToUIImage(_ imageBuffer: CVImageBuffer) -> UIImage {
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        
        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        
        let quartzImage = context!.makeImage()
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let image = UIImage(cgImage: quartzImage!, scale: 1.0, orientation: .right)
        
        return image
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if let destination = segue.destination as? TrialViewController {
            
            // last activity
            destination.activityID = session.activities.count-1
        }
    }
}

extension CameraViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        detectBone(outputFileURL)
//        moveVideoToPhotoLibrary(outputFileURL)
    }
}

//extension CameraViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
//    func selectVideo() {
//        let imagePickerController = UIImagePickerController()
//        imagePickerController.sourceType = .photoLibrary
//        imagePickerController.delegate = self as UIImagePickerControllerDelegate & UINavigationControllerDelegate
//        imagePickerController.mediaTypes = ["public.movie"]
//        present(imagePickerController, animated: true, completion: nil)
//    }
//
//    @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
//        selectedFileURL = info["UIImagePickerControllerReferenceURL"] as? URL
//        picker.dismiss(animated: true, completion: nil)
//    }
//}

class UILabelStroked: UILabel {
    var strokedText: String = "" {
        willSet(text) {
            let strokeTextAttributes = [
                NSAttributedStringKey.strokeColor : UIColor.white,
                NSAttributedStringKey.foregroundColor : UIColor.black,
                NSAttributedStringKey.strokeWidth : -2.0
            ] as [NSAttributedStringKey : Any]
            
            attributedText = NSMutableAttributedString(string: text, attributes: strokeTextAttributes)
        }
    }
}
