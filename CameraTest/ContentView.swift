//
//  ContentView.swift
//  CameraTest
//
//  Created by Anders Borum on 22/11/2024.
//

import SwiftUI
import AVFoundation
import Metal
import MetalKit

struct CameraMetalView: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.framebufferOnly = false
        mtkView.colorPixelFormat = .bgra8Unorm
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    class Coordinator: NSObject, MTKViewDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
        private var captureSession: AVCaptureSession!
        private var videoOutput: AVCaptureVideoDataOutput!
        private var textureCache: CVMetalTextureCache!
        private var currentTexture: MTLTexture?

        private let device: MTLDevice
        private let commandQueue: MTLCommandQueue
        private var pipelineState: MTLRenderPipelineState!

        override init() {
            device = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()

            setupMetalPipeline()
            setupCamera()
            CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        }

        func setupMetalPipeline() {
            // Load shaders from the default library
            let library = device.makeDefaultLibrary()
            let vertexFunction = library?.makeFunction(name: "vertexMain")
            let fragmentFunction = library?.makeFunction(name: "textureFragment")

            // Create the render pipeline descriptor
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            // Compile the pipeline state
            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                fatalError("Unable to create pipeline state: \(error)")
            }
        }

        func setupCamera() {
            captureSession = AVCaptureSession()
            captureSession.sessionPreset = .medium

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let cameraInput = try? AVCaptureDeviceInput(device: camera) else {
                fatalError("Unable to access front camera.")
            }

            captureSession.addInput(cameraInput)

            videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.processing"))

            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }

            captureSession.startRunning()
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            currentTexture = convertToTexture(pixelBuffer: pixelBuffer)
        }

        private func convertToTexture(pixelBuffer: CVPixelBuffer) -> MTLTexture? {
            guard let textureCache = textureCache else {
                print("Texture cache is nil")
                return nil
            }

            var cvMetalTexture: CVMetalTexture?
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)

            let status = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                pixelBuffer,
                nil,
                .bgra8Unorm,
                width,
                height,
                0,
                &cvMetalTexture
            )

            if status != kCVReturnSuccess {
                print("Error: Unable to create Metal texture from pixel buffer")
                return nil
            }

            return CVMetalTextureGetTexture(cvMetalTexture!)
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let texture = currentTexture,
                  let descriptor = view.currentRenderPassDescriptor else {
                return
            }

            let commandBuffer = commandQueue.makeCommandBuffer()
            let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor)

            // Set up the render pipeline state and texture
            renderEncoder?.setRenderPipelineState(pipelineState)
            renderEncoder?.setFragmentTexture(texture, index: 0)

            // Draw a full-screen quad
            renderEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder?.endEncoding()

            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle resizing if necessary
        }
    }
}

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.black
            .ignoresSafeArea()

            Button("Hello World", action: {})
            .foregroundStyle(.black)
            .font(.largeTitle)            
            .padding()
            .background(
                CameraMetalView()
                .cornerRadius(17)
            )
        }
    }
}

#Preview {
    ContentView()
}
