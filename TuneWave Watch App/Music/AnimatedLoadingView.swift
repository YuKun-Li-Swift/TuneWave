import SwiftUI
import CoreLocation

import SwiftUI
import SceneKit


struct AnimatedLoadingView: View {
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .aspectRatio(1, contentMode:    .fit)
            .overlay(alignment: .center) {
                Model3DView()
            }
    }
}

@Observable
class SceneModelShip {
    var sceneModel:SceneModel = SceneModel()
}
actor SceneModel {
    var scene:SCNScene?
    func load() throws {
        if let scene = SCNScene(named: "YiMusicLogo.usdz") {
            self.scene = scene
        } else {
            throw SceneLoadError.noFile
        }
    }
    enum SceneLoadError:Error,LocalizedError {
    case noFile
        var errorDescription: String? {
            switch self {
            case .noFile:
                "找不到3D文件"
            }
        }
    }
}

//省电模式：不开动画效果
//视障人士：不喜欢动画效果
//在设置里增加这个动画选项
struct Model3DView: View {
    @Environment(SceneModelShip.self)
    var sceneModelShip
    @State
    var scene:SCNScene?
    @State
    var loaded = false
    @State
    var blurDone = false
    @State
    var scaleDone = false
    @State
    var loadingError = false
    var body: some View {
        VStack {
            if !loadingError {
                SceneKit.SceneView(scene: scene, pointOfView: nil, options: [.allowsCameraControl,.autoenablesDefaultLighting,.jitteringEnabled,.temporalAntialiasingEnabled], preferredFramesPerSecond: 60, antialiasingMode: .multisampling4X, delegate: nil, technique: nil)
                //allowsCameraControl：拖曳手势
                //autoenablesDefaultLighting：光源
                //temporalAntialiasingEnabled：时序抗锯齿
                //jitteringEnabled：得到更高质量的渲染效果，起着防抖动防锯齿的效果。
                //multisampling4X：4倍抗锯齿
                    .scaleEffect(scaleDone ? 1 : 2, anchor: .center)
                //            .opacity(loaded ? 1 : 0)
                    .blur(radius: blurDone ? 0 : 23)
                //加载完成后淡入效果
                    .task {
                        await loadScene()
                    }
            } else {
                HomeMakeSlashSymbol(symbolName: "view.3d", accessibilityLabel: "3D模型不可用")
                    .imageScale(.large).bold()
            }
        }
    }
    func loadScene() async {
        //缓存一下，不然每点一首歌就加载一次那还得了？
        guard let scene = await sceneModelShip.sceneModel.scene else {
            self.loadingError = true
            return
        }
        //因为默认的viewport尺寸会刚好让物品填满整个viewport，这太大了，但直接缩小viewport会让手势触发范围也缩小，所以还是缩小物体吧
        scene.rootNode.scale = .init(x: 0.75, y: 0.75, z: 0.75)
        //scene在SwiftUI中不支持透明背景，因此设为黑色
        scene.background.contents = UIColor.black
        
        var rotationAction = {
            if Bool.random() {
                SCNAction.rotateBy(x: 0, y: 0, z: CGFloat(2 * Double.pi), duration: 1.2)
            } else {
                SCNAction.rotateBy(x: CGFloat(2 * Double.pi), y: 0, z: 0, duration: 1.2)
            }
        }()
        rotationAction.timingMode = .easeOut

     
        self.scene = scene
        try? await Task.sleep(nanoseconds: 1000000000/3)
        withAnimation(.easeIn) {
            blurDone = true
        }
        withAnimation(.easeOut(duration: 1)) {
            scaleDone = true
        }
        await scene.rootNode.runAction(rotationAction)
   
    }
}







struct SpeedometerGaugeStyle: GaugeStyle {
    private var purpleGradient = AngularGradient(gradient: Gradient(colors: [Color.red, Color.orange, Color.yellow, Color.green, Color.blue]), center: .center)

    func makeBody(configuration: Configuration) -> some View {
        ZStack {

            Circle()
                .foregroundStyle(Material.ultraThin)

            Circle()
                
                .trim(from: 0, to: 0.75 * configuration.value)
                
                .stroke(purpleGradient, style: StrokeStyle(lineWidth:10,lineCap: .round))
                
                .rotationEffect(.degrees(135))

            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.black, style: StrokeStyle(lineWidth: 5, lineCap: .butt, lineJoin: .round, dash: [1, 34], dashPhase: 0.0))
                .rotationEffect(.degrees(135))

            VStack {
                configuration.currentValueLabel
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                Text("MB/s")
                    .font(.system(.footnote, design: .rounded))
                    .bold()
                    .foregroundColor(.gray)
                    
            }

        }
        .frame(width: 100, height: 100)

    }

}

struct CustomGaugeView: View {

    @Binding var currentSpeed:Double
    @Binding var maxSpeed:Double

    var body: some View {
        Gauge(value: currentSpeed, in: 0...maxSpeed) {
            Image(systemName: "gauge.medium")
                .font(.system(size: 50.0))
        } currentValueLabel: {
            Text("\(currentSpeed.LSformattedWithDecimal(2))")
                .contentTransition(.numericText())
                
        }
        .gaugeStyle(SpeedometerGaugeStyle())

    }
}


extension Numeric {
    
    func LSformattedWithDecimal(_ places:Int) -> String {
        let number = self as! NSNumber // 强制类型转换为NSNumber以使用NSNumberFormatter
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = places
        return formatter.string(from: number) ?? "\(self)"
    }
   
}


struct SpeedometerView: View {
    @State private var isAnimating = false
    @State
    var startHaptic = UUID()
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(gradient: Gradient(colors: [Color.black, Color.blue]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)
    //            ZStack {
                   
    //                    .blur(radius: 23)
    //                CustomGaugeView()
    //            }
    //
                
                VStack {
                    HStack {
                        Spacer()
                        Text("Peak Speed: \(downloadManager.peakSpeed, specifier: "%.2f") MB/s")
                            .font(.body)
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.1)
                            .scaledToFit()
                            .lineLimit(1)
                        Spacer()
                    }

                    // Dynamic Speedometer
                    ZStack {
                        
                        
    //                    Circle()
    //                        .stroke(lineWidth: 20)
    //                        .fill(AngularGradient(gradient: Gradient(colors: [Color.red, Color.orange, Color.yellow, Color.green, Color.blue]), center: .center))
    //                        .rotationEffect(Angle(degrees: -90))
                        CustomGaugeView(currentSpeed: $downloadManager.realTimeSpeed,maxSpeed: .constant(20))
                            .scaleEffect(isAnimating ? 1.1 : 1.0, anchor: .center)
                            .animation(.smooth.repeatForever(autoreverses: true),value:isAnimating)
                            .onAppear {
                                isAnimating = true
                            }
                            .zIndex(10)
    //
    //                    Text("\(locationManager.speed, specifier: "%.2f") km/h")
    //                        .font(.system(size: 72))
    //                        .fontWeight(.bold)
    //                        .foregroundColor(.white)
                      
                    }
                    .padding(.horizontal)
                    .onTapGesture {
                        if downloadManager.inTesting == false {
                            downloadManager.startDownload(url: URL(string: "http://ling-bucket.oss-cn-beijing.aliyuncs.com/apple/random_800mb_file.bin")!)
                            startHaptic = UUID()
                        }
                    }
                    .sensoryFeedback(.increase, trigger: startHaptic)
                    
                    VStack {
                        
                               if downloadManager.inTesting {
                                   Button(action: {
                                       downloadManager.cancelDownload()
                                       
                                   }) {
                                       Text("Cancel Download")
                                           .font(.body)
                                           .padding()
                                           .background(Color.red)
                                           .foregroundColor(.white)
                                           .cornerRadius(10)
                                   }
                                 
                               } else {
                                   Button(action: {
                                                    downloadManager.startDownload(url: URL(string: "http://ling-bucket.oss-cn-beijing.aliyuncs.com/apple/random_800mb_file.bin")!)
                                       startHaptic = UUID()
                                                }) {
                                                    Text("Start Download")
                                                        .font(.body)
                                                        .padding()
                                                        .background(Color.blue)
                                                        .foregroundColor(.white)
                                                        .cornerRadius(10)
                                                }
                               }
                           
                    }
                    .buttonStyle(.plain)
                    .ignoresSafeArea(.all, edges: .bottom)
                    
                 
                }
                
            }
            .navigationTitle("Download Speed")
        }
     
    }
    
    @StateObject private var downloadManager = DownloadManager()
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    @Published var speed: Double = 0.0
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            // 将速度从m/s转换为km/h
            speed = location.speed >= 0 ? location.speed * 3.6 : 0
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to update location: \(error.localizedDescription)")
    }
}



import SwiftUI
import Combine


class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task { @MainActor in
            withAnimation(.smooth) {
                inTesting = false
            }
        }
    }
    @Published
    var inTesting = false
    @Published var realTimeSpeed: Double = 0.0
    @Published var peakSpeed: Double = 0.0
    private var session: URLSession!
    private var downloadTask: URLSessionDownloadTask?
    private var dataReceived: Int = 0
    private var speeds: [Double] = []
    private var lastUpdateTime: Date = Date()

    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
    }

    func startDownload(url: URL) {
        // 如果有正在进行的下载任务，先取消
        cancelDownload()
        
        self.dataReceived = 0
        self.speeds = []
        self.peakSpeed = 0.0
        self.lastUpdateTime = Date()

        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        Task { @MainActor in
            withAnimation(.smooth) {
                inTesting = true
            }
        }
        let currentTime = Date()
        let elapsedTime = currentTime.timeIntervalSince(lastUpdateTime)
        
        if elapsedTime >= 1.0 {
            let speed = Double(dataReceived) / elapsedTime / (1024 * 1024) // Convert to MB/s
            speeds.append(speed)
            
            Task { @MainActor in
                withAnimation(.easeOut) {
                    inTesting = true
                    realTimeSpeed = speeds.last ?? 0.0
                    peakSpeed = speeds.max() ?? 0.0
                }
            }
           
            dataReceived = 0
            lastUpdateTime = currentTime
        } else {
            dataReceived += Int(bytesWritten)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            withAnimation(.smooth) {
                inTesting = false
            }
        }
        if let error = error {
            print("Download failed: \(error)")
        } else {
            print("Download finished")
        }
    }
}
