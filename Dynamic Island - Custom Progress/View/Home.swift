//
//  Home.swift
//  Dynamic Island - Custom Progress
//
//  Created by Vladimir Sukhikh on 2022-10-06.
//

import SwiftUI

struct Home: View {
    @StateObject var progressBar: DynamicProgress = .init()
    @State var sampleProgress: CGFloat = 0
    
    var body: some View {
        Button(progressBar.isAdded ? "Stop" : "Start") {
            if progressBar.isAdded {
                progressBar.removeProgressWithAnimations()
            } else {
                let config = ProgressConfig(title: "Downloading Complete!", progressImage: "icloud.and.arrow.down", expandedImage: "checkmark.circle", tint: .yellow, rotationEnabled: true)
                progressBar.addProgressView(config: config)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 100)
        
        //Progress Using Timer
        .onReceive(Timer.publish(every: 0.01, on: .main, in: .default).autoconnect()) { _ in
            if progressBar.isAdded {
                sampleProgress += 0.3
                progressBar.updateProgressView(to: sampleProgress / 100)
            } else {
                sampleProgress = 0
            }
        }
        .statusBarHidden(progressBar.hideStatusBar)
    }
}

struct Home_Previews: PreviewProvider {
    static var previews: some View {
        Home()
    }
}

class DynamicProgress:  NSObject, ObservableObject {
    @Published var isAdded: Bool = false
    @Published var hideStatusBar: Bool = false
    
    func addProgressView(config: ProgressConfig)  {
        if (rootController().view.viewWithTag(1009) == nil) {
            let swiftUIView = DynamicProgressView(config: config)
                .environmentObject(self)
            let hostingView = UIHostingController(rootView: swiftUIView)
            hostingView.view.frame = screenSize()
            hostingView.view.backgroundColor = .clear
            hostingView.view.tag = 1009
            rootController().view.addSubview(hostingView.view)
            isAdded = true
        }
    }
    
    func updateProgressView(to: CGFloat) {
        NotificationCenter.default.post(name: NSNotification.Name("UPDATE_PROGRESS"), object: nil, userInfo: [
            "progress": to
        ])
    }
    
    func removeProgressView() {
        if let view = rootController().view.viewWithTag(1009) {
            view.removeFromSuperview()
            isAdded = false
        }
    }
    
    func removeProgressWithAnimations() {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "CLOSE_PROGRESS_VIEW") , object: nil)
    }
    
    func screenSize() -> CGRect {
        guard let window = UIApplication.shared.connectedScenes.first as? UIWindowScene
        else {
            return .zero
        }
        return window.screen.bounds
    }
    
    func rootController() -> UIViewController {
        guard let window = UIApplication.shared.connectedScenes.first as? UIWindowScene
        else {
            return .init()
        }
        
        guard let root = window.windows.first?.rootViewController else {
            return .init()
        }
        
        return root
    }
}


struct DynamicProgressView: View {
    var config: ProgressConfig
    @EnvironmentObject var progressBar: DynamicProgress
    
    //Animation Properties
    @State var showProgressView: Bool = false
    @State var progress: CGFloat = 0
    @State var showAlert: Bool = false
    
    var body: some View {
        Canvas { ctx, size in
            ctx.addFilter(.alphaThreshold(min: 0.5, color: .black))
            ctx.addFilter(.blur(radius: 5))
            
            ctx.drawLayer { context in
                for index in [1, 2] {
                    if let resolvedImage = ctx.resolveSymbol(id: index) {
                        context.draw(resolvedImage, at: CGPoint(x: size.width / 2, y: 29))
                    }
                }
            }
        } symbols: {
            ProgressComponents()
                .tag(1)
            ProgressComponents(isCircle: true)
                .tag(2)
        }
        .overlay(alignment: .top) {
            ProgressView()
                .offset(y: 11)
        }
        .overlay(alignment: .top) {
            CustomAlertView()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showProgressView = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("CLOSE_PROGRESS_VIEW"))) { _ in
            showProgressView = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                progressBar.removeProgressView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("UPDATE_PROGRESS"))) { output in
            if let info = output.userInfo, let progress = info["progress"] as? CGFloat {
                if progress < 1.0 {
                    self.progress = progress
                    
                    if (progress * 100).rounded() == 100.0 {
                        showProgressView = false
                        showAlert = true
                        
                        //Hide Status Bar When Half Alert is Opened
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                            progressBar.hideStatusBar = true
                        }
                        
                        //Removing Alert After 2-3s
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showAlert = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                progressBar.hideStatusBar = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                progressBar.removeProgressView()
                            }
                        }
                    }
                }
            }
        }
    }
    
    //Custom Dynamic Island Alert
    @ViewBuilder
    func CustomAlertView() -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            
            Capsule()
                .fill(.black)
                .frame(width: showAlert ? size.width : 126, height: showAlert ? size.height : 37)
                .overlay(content: {
                    //Alert Content
                    HStack(spacing: 13) {
                        Image(systemName: config.expandedImage)
                            .symbolRenderingMode(.multicolor)
                            .font(.largeTitle)
                            .foregroundStyle(.white, .blue, .white)
                        
                        HStack(spacing: 6) {
                            Text(config.title)
                                .font(.system(size: 13))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                        }
                        .lineLimit(1)
                        .contentTransition(.opacity)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .offset(y: 12)
                    }
                    .padding(.horizontal, 12)
                    .blur(radius: showAlert ? 0 : 5)
                    .opacity(showAlert ? 1 : 0)
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: 65)
        .padding(.horizontal, 18)
        .offset(y: 11)
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.7).delay(showAlert ? 0.4 : 0), value: showAlert)
    }
    
    //Progress View
    @ViewBuilder
    func ProgressView() -> some View {
        ZStack {
            Image(systemName: config.progressImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .fontWeight(.semibold)
                .frame(width: 12, height: 12)
                .foregroundColor(.white)
            
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.25), lineWidth: 4)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(config.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(Angle(degrees: -90))
            }
            .frame(width: 23, height: 23)
        }
        .frame(width: 37, height: 37)
        .frame(width: 127, alignment: .trailing)
        .offset(x: showProgressView ? 45 : 0)
        .opacity(showProgressView ? 1 : 0)
        .animation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.7), value: showProgressView)
    }
    
    //Progress Bar Components
    @ViewBuilder
    func ProgressComponents(isCircle: Bool = false) -> some View {
        if isCircle {
            Circle()
                .fill(.black)
                .frame(width: 37, height: 37)
                .frame(width: 127, alignment: .trailing)
                .offset(x: showProgressView ? 45 : 0)
                .scaleEffect(showProgressView ? 1 : 0.45, anchor: .trailing)
                .animation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.7), value: showProgressView)
        } else {
            Capsule()
                .fill(.black)
                .frame(width: 127, height: 37)
        }
    }
}
