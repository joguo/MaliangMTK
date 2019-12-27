//
//  AppDelegate.swift
//  MetalViewRed
//
//  Created by jo on 2019/12/27.
//

import Cocoa
import MetalKit
import simd

struct Vertex {
    var position: vector_float4
    var textCoord: vector_float2
    
    init(position: CGPoint, textCoord: CGPoint) {
        self.position = [Float(position.x), Float(position.y), 0 ,1]
        self.textCoord = [Float(textCoord.x), Float(textCoord.y)]
    }
}

class Matrix {
    
    private(set) var m: [Float]
    
    static var identity = Matrix()
    
    private init() {
        m = [1, 0, 0, 0,
             0, 1, 0, 0,
             0, 0, 1, 0,
             0, 0, 0, 1
        ]
    }
    
    @discardableResult
    func translation(x: Float, y: Float, z: Float) -> Matrix {
        m[12] = x
        m[13] = y
        m[14] = z
        return self
    }
    
    @discardableResult
    func scaling(x: Float, y: Float, z: Float)  -> Matrix  {
        m[0] = x
        m[5] = y
        m[10] = z
        return self
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, MTKViewDelegate {

    @IBOutlet weak var window: NSWindow!

    @IBOutlet weak var metalView: MTKView!

    private var commandQueue: MTLCommandQueue?

    private var pipelineState: MTLRenderPipelineState!
    private var render_target_vertex: MTLBuffer!
    private var render_target_uniform: MTLBuffer!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.delegate = self
        
        commandQueue = metalView.device?.makeCommandQueue()
        
        setupTargetUniforms()

        do {
            try setupPiplineState()
        } catch {
            fatalError("Metal initialize failed: \(error.localizedDescription)")
        }
    }
    
    private func setupTargetUniforms() {
        let size = metalView.frame.size
        let w = size.width, h = size.height
        let vertices = [
            Vertex(position: CGPoint(x: 0 , y: 0), textCoord: CGPoint(x: 0, y: 0)),
            Vertex(position: CGPoint(x: w , y: 0), textCoord: CGPoint(x: 1, y: 0)),
            Vertex(position: CGPoint(x: 0 , y: h), textCoord: CGPoint(x: 0, y: 1)),
            Vertex(position: CGPoint(x: w , y: h), textCoord: CGPoint(x: 1, y: 1)),
        ]
        render_target_vertex = metalView.device?.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: .cpuCacheModeWriteCombined)
        
        let metrix = Matrix.identity
        metrix.scaling(x: 2 / Float(size.width), y: -2 / Float(size.height), z: 1)
        metrix.translation(x: -1, y: 1, z: 0)
        render_target_uniform = metalView.device?.makeBuffer(bytes: metrix.m, length: MemoryLayout<Float>.size * 16, options: [])
    }
    
    private func setupPiplineState() throws {
        
        let library = try metalView.device?.makeDefaultLibrary(bundle: Bundle.main)
        let vertex_func = library?.makeFunction(name: "vertex_render_target")
        let fragment_func = library?.makeFunction(name: "fragment_render_target")
        let rpd = MTLRenderPipelineDescriptor()
        rpd.vertexFunction = vertex_func
        rpd.fragmentFunction = fragment_func
        rpd.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        //        rpd.colorAttachments[0].isBlendingEnabled = true
        //        rpd.colorAttachments[0].alphaBlendOperation = .add
        //        rpd.colorAttachments[0].rgbBlendOperation = .add
        //        rpd.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        //        rpd.colorAttachments[0].sourceAlphaBlendFactor = .one
        //        rpd.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        //        rpd.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipelineState = try metalView.device?.makeRenderPipelineState(descriptor: rpd)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
        
    }

    func draw(in view: MTKView) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        let attachment = renderPassDescriptor.colorAttachments[0]
        attachment?.clearColor = metalView.clearColor
        attachment?.texture = metalView.currentDrawable?.texture
        attachment?.loadAction = .clear
        attachment?.storeAction = .store
        
        let commandBuffer = commandQueue?.makeCommandBuffer()
        
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        
        commandEncoder?.setRenderPipelineState(pipelineState)
        
        commandEncoder?.setVertexBuffer(render_target_vertex, offset: 0, index: 0)
        commandEncoder?.setVertexBuffer(render_target_uniform, offset: 0, index: 1)
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: metalView.colorPixelFormat,
                                                                         width: Int(metalView.frame.size.width),
                                                                         height: Int(metalView.frame.size.height),
                                                                         mipmapped: false)
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        let texture = metalView.device?.makeTexture(descriptor: textureDescriptor)
        commandEncoder?.setFragmentTexture(texture, index: 0)
        commandEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        commandEncoder?.endEncoding()
        if let drawable = metalView.currentDrawable {
            commandBuffer?.present(drawable)
        }
        commandBuffer?.commit()
    }
}



